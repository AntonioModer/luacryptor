
local m = {}

function m.cleanSource(src)
    src = src:gsub("function [%w_%.]+%(", "function (")
    src = src:gsub(".*function", "function")
    return src
end

function m.dump(str)
    if not m.numtab then
        m.numtab = {}
        for i = 0, 255 do
            m.numtab[string.char(i)] = ("%3d,"):format(i)
        end
    end
    str = str
        :gsub(".", m.numtab)
        :gsub(("."):rep(60), "%0\n")
    if str:sub(-1, -1) == ',' then
        str = str:sub(1, -2)
    end
    return str
end

function m.fileContent(fname)
    local f = assert(io.open(fname,"rb"))
    local content = f:read("*a")
    f:close()
    return content
end

function m.encryptFileContent(fname, password)
    local lc = require 'luacryptorext'
    local content = m.fileContent(fname)
    return lc.encrypt(content, password)
end

function m.embed_luaopen() return [[
LUALIB_API int luaopen_@modname@(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "__luacryptor_pwd");
    const char* password = lua_tostring(L, -1);
    lua_pop(L, 1);
    if (!password) {
        printf("Set password in regiter property "
            "__luacryptor_pwd\n");
        return 0;
    }
    const char lua_enc_dump[] = { @lua_enc_dump@ };
    lua_pushcfunction(L, twofish_decrypt);
    lua_pushlstring(L, lua_enc_dump, sizeof(lua_enc_dump));
    lua_pushstring(L, password);
    lua_call(L, 2, 1);
    if (lua_type(L, -1) != LUA_TSTRING) {
        printf("Failed to decrypt Lua source\n");
        return 0;
    }
    size_t orig_size;
    const char* orig = lua_tolstring(L, -1, &orig_size);
    int status = luaL_loadbuffer(L, orig, orig_size,
        "@basename@");
    if (status) {
        printf("%s\n", lua_tostring(L, -1));
        printf("Wrong password?\n");
        lua_pop(L, 2); // orig, error message
        return 0;
    }
    lua_pcall(L, 0, 1, 0);
    return 1; // chunk execution result
}]] end

function m.module_names(fname_lua)
    local fname_c = fname_lua:gsub('.lua$', '.c')
    local basename = fname_lua:gsub('.lua$', '')
    local modname = basename
    modname = modname:gsub('.+/', '')
    modname = modname:gsub('.+\\', '')
    return fname_c, basename, modname
end

function m.lua2c(fname_lua, password)
    local lua_enc = m.encryptFileContent(fname_lua, password)
    local lua_enc_dump = m.dump(lua_enc)
    local fname_c, basename, modname = m.module_names(fname_lua)
    local f_c = io.open(fname_c, 'w')
    local lc = require 'luacryptorext'
    f_c:write(lc.luacryptorbase)
    local ttt = m.embed_luaopen():gsub('@[%w_]+@', {
        ['@modname@'] = modname,
        ['@basename@'] = basename,
        ['@lua_enc_dump@'] = lua_enc_dump,
    })
    f_c:write(ttt)
    f_c:close()
end

function m.encrypt_function_src(fname_lua, password)
    local mod = assert(loadfile(fname_lua))()
    for name, func in pairs(mod) do
        print(name)
    end
end

-- http://stackoverflow.com/a/4521960
if not pcall(debug.getlocal, 4, 1) then
    if arg[1] == 'embed' then
        local fname = arg[2]
        local password = arg[3]
        m.lua2c(fname, password)
    elseif arg[1] == 'dump' then
        local fname = arg[2]
        local content = m.fileContent(fname)
        print(m.dump(content))
    elseif arg[1] == 'enc-func-src' then
        local fname = arg[2]
        local password = arg[3]
        m.encrypt_function_src(fname, password)
    else
        print([[Usage:
        lua luacryptor.lua dump any_file
        lua luacryptor.lua embed target.lua password
        lua luacryptor.lua enc-func-src target.lua password
        ]])
    end
end

return m

