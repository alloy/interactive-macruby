IMConsole = {
	unexpandableRow: function(object) {
		var row    = new Element('tr', { 'class': 'basic-node' });
		var prefix = new Element('td', { 'class': 'prefix' });
		var value  = new Element('td', { 'class': 'value' });
		prefix.innherText = object.prefix;
		value.innerText = object.value;
		row.appendChild(prefix);
		row.appendChild(value);
		return row;
	},

	addRow: function(object) {
		console.log(object);
		$('console-messages').appendChild(IMConsole.unexpandableRow(object));
	},
};
