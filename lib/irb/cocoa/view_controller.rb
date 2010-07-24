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
      # add one extra which is the input row
      @results.size + 1
    end
  end
  
  def outlineView(outlineView, isItemExpandable: item)
    false
  end
  
  def outlineView(outlineView, child: index, ofItem: item)
    if item == nil
      if index == @results.size
        :input
      else
        @results[index]
      end
    end
  end
  
  def outlineView(outlineView, objectValueForTableColumn: column, byItem: item)
    if item == :input
      if column.identifier == "prompt"
        "irb>"
      else
        ""
      end
    elsif item
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