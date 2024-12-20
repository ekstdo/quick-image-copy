

blueprint_files = files(
    'ui/main.blp',
    'ui/emojis.blp',
    'ui/images.blp',
)

blueprint_target = custom_target('blueprints',
    input: blueprint_files,
    output: '.',
    command: [ find_program('blueprint-compiler'), 'batch-compile', '@OUTPUT@', '@CURRENT_SOURCE_DIR@', '@INPUT@' ],
)

resources = gnome.compile_resources(
    'resources',
    'quick-copy.gresource.xml',
    source_dir: meson.current_build_dir(),
    dependencies: blueprint_target
)
