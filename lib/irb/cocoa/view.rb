class IRBView < NSView
  attr_reader :viewController, :outlineView
  
  def initWithViewController(viewController)
    if init
      @outlineView = NSOutlineView.alloc.init
      @outlineView.headerView = nil
      # @outlineView.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle
      @outlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone
      
      promptColumn = NSTableColumn.alloc.initWithIdentifier("prompt")
      promptColumn.editable = false
      @outlineView.addTableColumn(promptColumn)
      
      valueColumn = NSTableColumn.alloc.initWithIdentifier("value")
      @outlineView.addTableColumn(valueColumn)
      @outlineView.outlineTableColumn = valueColumn
      @outlineView.indentationPerLevel = 0
      
      @scrollView = NSScrollView.alloc.init
      @scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable
      @scrollView.documentView = @outlineView
      addSubview(@scrollView)
      
      self.viewController = viewController
      
      self
    end
  end
  
  # http://cocoawithlove.com/2008/07/better-integration-for-nsviewcontroller.html
  def setViewController(viewController)
    # ownNextResponder              = nextResponder
    # self.nextResponder            = viewController
    # viewController.nextResponder  = ownNextResponder
    
    @viewController               = viewController
    
    @outlineView.dataSource       = @viewController
    @outlineView.delegate         = @viewController
  end
  
  # def setNextResponder(nextResponder)
  #   if @viewController
  #     @viewController.nextResponder = nextResponder
  #   else
  #     super
  #   end
  # end
end