-- filename: lua/econet_cybo_overlay.lua
-- destination: eco_restoration_shard/lua/econet_cybo_overlay.lua

local ffi = require("ffi")

ffi.cdef[[
    char* econet_get_ker_targets(const char* dbpath, const char* reponame);
    char* econet_get_blast_radius_for_node(const char* dbpath, const char* nodeid);
    char* econet_get_workload_trends_for_node(const char* dbpath, const char* nodeid);
    void  econet_free_json(char* ptr);
]]

-- Adjust the library name/path to your built cdylib (.so/.dll)
local lib = ffi.load("eco_restoration_shard")

local M = {}

local function read_json_ptr(ptr)
    if ptr == nil then
        return nil, "null pointer"
    end
    local s = ffi.string(ptr)
    lib.econet_free_json(ptr)
    return s, nil
end

function M.get_ker_targets(dbpath, reponame)
    local c = lib.econet_get_ker_targets(dbpath, reponame)
    return read_json_ptr(c)
end

function M.get_blast_radius(dbpath, nodeid)
    local c = lib.econet_get_blast_radius_for_node(dbpath, nodeid)
    return read_json_ptr(c)
end

function M.get_workload_trends(dbpath, nodeid)
    local c = lib.econet_get_workload_trends_for_node(dbpath, nodeid)
    return read_json_ptr(c)
end

return M
