class IRBViewController < NSViewController
  def initWithObject(object, binding: binding)
    if init
      @results = [{ "prompt" => "irb>", "result" => ":ok" }]
      
      @resultCell = NSTextFieldCell.alloc.init
      @resultCell.editable = false
      @inputCell = NSTextFieldCell.alloc.init
      @inputCell.editable = true
      
      self
    end
  end
  
  def loadView
    self.view = IRBView.alloc.initWithViewController(self)
  end
  
  # outline view data source methods
  
  def outlineView(outlineView, numberOfChildrenOfItem: item)
    if item == nil
      # p "number of items: #{@results.size + 1}"
      @results.size + 1
    end
  end
  
  def outlineView(outlineView, isItemExpandable: item)
    # p outlineView, item
    false
  end
  
  def outlineView(outlineView, child: index, ofItem: item)
    # p outlineView, child, item
    if item == nil
      # p "asked for child at #{index}"
      if index == @results.size
        # p "INPUT!"
        :input
      else
        # p @results[index]
        @results[index]
      end
    end
  end
  
  def outlineView(outlineView, objectValueForTableColumn: column, byItem: item)
    # p outlineView, column, item
    # p item
    if item == nil
      nil
    elsif item == :input
      # p "asked for input"
      if column.identifier == "prompt"
        "irb>"
      else
        ""
      end
    else
      # p "asked for object value for #{item.inspect}"
      # p column.identifier
      item[column.identifier]
    end
  end
  
  # outline view delegate methods
  
  def outlineView(outlineView, dataCellForTableColumn: column, item: item)
    if column
      if item == :input
        @inputCell
      else
        @resultCell
      end
    end
  end
end