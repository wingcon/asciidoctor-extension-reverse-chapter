# code baseed on thread in forum:
# https://asciidoctor.zulipchat.com/#narrow/stream/288690-users.2Fasciidoctor-pdf/topic/Change.20order.20of.20Chapter.2FSection.20numbering
# Author: r0ckarong
# MIT license
class NumberedSignifier < (Asciidoctor::Converter.for 'pdf')
    register_for 'pdf'

    Asciidoctor::Section.prepend (Module.new do
      def numbered_title opts = {}
        @cached_numbered_title ||= nil
        unless @cached_numbered_title
          doc = @document
          if @numbered && !@caption && (slevel = @level) <= (doc.attr 'sectnumlevels', 3).to_i
            @is_numbered = true
            if doc.doctype == 'book'
              case slevel
              when 0
                @cached_numbered_title = %(#{sectnum nil, ':'} #{title})
                signifier = doc.attributes['part-signifier'] || ((doc.attr_unspecified? 'part-signifier') ? 'Part' : '')
                @cached_formal_numbered_title = %(#{sectnum nil, ':'} #{signifier}#{signifier.empty? ? '' : ':'} #{@title})
              when 1
                @cached_numbered_title = %(#{sectnum} #{title})
                signifier = doc.attributes['chapter-signifier'] || ((doc.attr_unspecified? 'chapter-signifier') ? 'Chapter' : '')
                @cached_formal_numbered_title = %(#{sectnum} #{signifier}#{signifier.empty? ? '' : ':'} #{@title})
              else
                @cached_formal_numbered_title = @cached_numbered_title = %(#{sectnum} #{title})
              end
            else
              @cached_formal_numbered_title = @cached_numbered_title = %(#{sectnum} #{title})
            end
          elsif @level == 0
            @is_numbered = false
            @cached_numbered_title = @cached_formal_numbered_title = title
          else
            @is_numbered = false
            @cached_numbered_title = @cached_formal_numbered_title = captioned_title
          end
        end
        opts[:formal] ? @cached_formal_numbered_title : @cached_numbered_title
      end
    end
    )

    Asciidoctor::AbstractBlock.prepend (Module.new do
        def assign_caption value, caption_context = @context
          unless @caption || !@title || (@caption = value || @document.attributes['caption']) # rubocop:disable Style/GuardClause
              if (attr_name = Asciidoctor::CAPTION_ATTRIBUTE_NAMES[caption_context]) && (prefix = @document.attributes[attr_name])
                @caption = %(#{@numeral = @document.increment_and_store_counter %(#{caption_context}-number), self}. #{prefix}: )
                nil
              end
          end
        end
        def assign_numeral section
          @next_section_index = (section.index = @next_section_index) + 1
          if (like = section.numbered)
              if (sectname = section.sectname) == 'appendix'
                section.numeral = @document.counter 'appendix-number', 'A'
                section.caption = (caption = @document.attributes['appendix-caption']) ? %(#{section.numeral}. #{caption}: ) : %(#{section.numeral}. )
                # NOTE currently chapters in a book doctype are sequential even for multi-part books (see #979)
              elsif sectname == 'chapter' || like == :chapter
                section.numeral = (@document.counter 'chapter-number', 1).to_s
              else
                section.numeral = sectname == 'part' ? (Helpers.int_to_roman @next_section_ordinal) : @next_section_ordinal.to_s
                @next_section_ordinal += 1
              end
          end
          nil
        end
        def xreftext xrefstyle = nil
          if (val = reftext) && !val.empty?
            val
          # NOTE xrefstyle only applies to blocks with a title and a caption or number
          elsif xrefstyle && @title && !@caption.nil_or_empty?
            case xrefstyle
            when 'full'
              quoted_title = sub_placeholder (sub_quotes @document.compat_mode ? %q(``%s'') : '"`%s`"'), title
              if @numeral && (caption_attr_name = Asciidoctor::CAPTION_ATTRIBUTE_NAMES[@context]) && (prefix = @document.attributes[caption_attr_name])
                %(#{@numeral} #{prefix}, #{quoted_title})
              else
                %(#{@caption.chomp '. '}, #{quoted_title})
              end
            when 'short'
              if @numeral && (caption_attr_name = Asciidoctor::CAPTION_ATTRIBUTE_NAMES[@context]) && (prefix = @document.attributes[caption_attr_name])
                %(#{@numeral} #{prefix})
              else
                @caption.chomp '. '
              end
            else # 'basic'
              title
            end
          else
            title
          end
        end
    end
    )


    Asciidoctor::Section.prepend (Module.new do
      def xreftext xrefstyle = nil
        if (val = reftext) && !val.empty?
          val
        elsif xrefstyle
          if @numbered
            case xrefstyle
            when 'full'
              if (type = @sectname) == 'chapter' || type == 'appendix'
                quoted_title = sub_placeholder (sub_quotes '_%s_'), title
              else
                quoted_title = sub_placeholder (sub_quotes @document.compat_mode ? %q(``%s'') : '"`%s`"'), title
              end
              if (signifier = @document.attributes[%(#{type}-refsig)])
                %(#{sectnum '.', ','} #{signifier} #{quoted_title})
              else
                %(#{sectnum '.', ','} #{quoted_title})
              end
            when 'short'
              if (signifier = @document.attributes[%(#{@sectname}-refsig)])
                %(#{sectnum '.', ''} #{signifier})
              else
                sectnum '.', ''
              end
            else # 'basic'
              (type = @sectname) == 'chapter' || type == 'appendix' ? (sub_placeholder (sub_quotes '_%s_'), title) : title
            end
          else # apply basic styling
            (type = @sectname) == 'chapter' || type == 'appendix' ? (sub_placeholder (sub_quotes '_%s_'), title) : title
          end
        else
          title
        end
      end
    end
    )
end
