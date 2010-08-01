IMConsole = {
	start: function() {
		$('console').observe('click', function(event) {
			var element = event.element();
			var row = element.up("tr");
			if (row.hasClassName("expandable")) {
				var prefix = row.firstChild;
				var value = row.lastChild;
				if (prefix.hasClassName("not-expanded")) {
					if (value.lastChild.tagName != 'TABLE') {
						var table = IMViewController.childrenTableForNode(row.id);
						value.appendChild(table);
					} else {
						value.lastChild.show();
					}
					prefix.removeClassName("not-expanded");
					prefix.addClassName("expanded");
				} else {
					prefix.removeClassName("expanded");
					prefix.addClassName("not-expanded");
					value.lastChild.hide();
				}
			}
		});
	}
};
