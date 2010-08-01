IMConsole = {
	start: function() {
		$('console').observe('click', function(event) {
			var element = event.element();
			if (element.tagName == "IMG") {
				var row = element.up("tr");
				if (row.hasClassName("expandable")) {
					var table = IMViewController.childrenTableForNode(row.id);
					row.lastChild.appendChild(table);
				}
			}
		});
	}
};
