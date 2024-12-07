sources = files('main.vala', 'ui/main-ui.vala', 'utils.vala', 'emojis.vala', 'ui-utils.vala')

app = executable(
	'quick-copy',
	resources,
	sources,
	dependencies: [glib_dep, gobject_dep, gtk_dep, libadwaita_dep, gee_dep, libsoup_dep, json_dep],
	install: true
)
