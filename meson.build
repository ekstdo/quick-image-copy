project('quick-copy', 'c', 'vala')

glib_dep = dependency('glib-2.0', version: '>=2.38')
gobject_dep = dependency('gobject-2.0')
gtk_dep = dependency('gtk4')
libadwaita_dep = dependency('libadwaita-1')
gee_dep = dependency('gee-0.8')
libsoup_dep = dependency('libsoup-3.0')
json_dep = dependency('json-glib-1.0')

name = meson.project_name()
version = meson.project_version()
output = name.to_lower()


gnome=import('gnome')

subdir('data')
subdir('src')



