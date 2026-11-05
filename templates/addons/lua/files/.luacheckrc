std = "lua54"
max_line_length = 100
exclude_files = { ".luarocks", "lua_modules" }

-- busted defines describe, it and the assert extensions in specs.
files["spec/**/*_spec.lua"] = { std = "+busted" }
