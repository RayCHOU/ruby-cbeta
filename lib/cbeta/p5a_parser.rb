class CBETA::P5aParser
  
  # @example
  #
  #   def handle_notes(e)
  #     ...
  #   end
  #
  #   def traverse(e)
  #     e.children.each { |c| handle_nodes(c) }
  #   end
  #
  #   xml_string = File.read(xml_file_name)
  #   parser = CBETA::P5aParser.new(xml_string, :traverse)
  #
  def initialize(xml_string, children_handler)
    @doc = Nokogiri::XML(s)
    @doc.remove_namespaces!()
    @children_handler = children_handler
  end

  # @param e [Nokogiri::XML::Element]
  # @param mode [String] 'html' or 'text', default value: 'html'
  # @return [Hash]
  #   回傳
  #     * :content [String] 要放在本文中的文字, 如果 mode=='html', 那麼本文文字會包含 footnote anchor
  #     * :footnote_text [String] 要放在 footnote 的文字
  #     * :footnote_resp [String]
  #       * 'orig': 表示這個註解是底本的註
  #       * 'CBETA': 表示這個註解是 CBETA 修訂過的註  
  def handle_note(e, mode='html')
    r = {
      content: '',
      footnote_resp: nil,
      footnote_text: nil
    }
    n = e['n']
    if e.has_attribute?('type')
      t = e['type']
      case t
      when 'equivalent' then return r
      when 'orig'       then return handle_note_orig(e, mode)
      when 'orig_biao'  then return handle_note_orig(e, mode, 'biao')
      when 'orig_ke'    then return handle_note_orig(e, mode, 'ke')
      when 'mod'
        r[:footnote_resp] = 'CBETA'
        r[:footnote_content] = @children_handler.call(e)
        if mode == 'html'
          r[:content] = "<a class='noteAnchor' href='#n#{n}'></a>"
        end
        return r
      when 'rest' then return r
      else
        return r if t.start_with?('cf')
      end
    end

    if e.has_attribute?('resp')
      return r if e['resp'].start_with? 'CBETA'
    end

    s = @children_handler.call(e)
    r[:content] = s
    if e.has_attribute?('place') && e['place']=='inline'
      if mode == 'html'
        r[:content] = "<span class='doube-line-note'>#{s}</span>"
      end
    end
    r
  end
  
  private

  def handle_note_orig(e, mode, anchor_type=nil)
    r = { footnote_resp: 'orig' }
    n = e['n']
    r[:footnote_content] = @children_handler.call(e)

    if mode == 'html'
      label = case anchor_type
      when 'biao' then " data-label='標#{n[-2..-1]}'"
      when 'ke'   then " data-label='科#{n[-2..-1]}'"
      else ''
      end
      r[:content] = "<a class='noteAnchor' href='#n#{n}'#{label}></a>"
    end
    
    r
  end

end