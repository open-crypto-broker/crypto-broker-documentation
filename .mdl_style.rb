# Enable all rules by default
all

# Unordered list indentation can also be 4 spaces
rule 'MD007', :indent => 4

# Extend line length, since each sentence should be on a separate line.
rule 'MD013', :line_length => 500

# There are files which can have the same header caption several times.
exclude_rule 'MD024'

# Not all Markdown files will start with a top level header, some have metadata.
exclude_rule 'MD041'
