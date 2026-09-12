package.path = './lib/?.lua;' .. package.path
local state = {failed=0, passed=0}
package.preload.http = function() return {get=function(args)
    state.requests = state.requests + 1
    return state.response, state.request_error
end} end
package.preload.json = function() return {decode=function() return state.decoded end} end
PLUGIN = {}
dofile('hooks/available.lua')
dofile('hooks/pre_install.lua')
local function test(name, fn)
    state.response, state.request_error, state.decoded, state.requests = nil, nil, nil, 0
    available_result = nil
    local ok, err = pcall(fn)
    if ok then state.passed=state.passed+1 else state.failed=state.failed+1; print('FAIL '..name..': '..tostring(err)) end
end
local function expect_error(fn, message)
    local ok, err=pcall(fn)
    assert(not ok, 'expected error')
    assert(tostring(err):find(message,1,true), tostring(err))
end
for _, failure in ipairs({'timeout','HTTP 503'}) do
    test('search failure and recovery '..failure, function()
        if failure=='timeout' then state.request_error='timeout' else state.response={status_code=503} end
        expect_error(function() PLUGIN:Available({}) end, failure)
        state.request_error=nil; state.response={status_code=200,body='index'}
        state.decoded={{version='v20.16.0',npm='10.8.1',lts='Iron'}}
        assert(PLUGIN:Available({})[1].version=='20.16.0')
        assert(state.requests==2, 'failed response was cached')
    end)
end
local cases = {
    {'windows','amd64','win-x64.zip'},
    {'windows','386','win-x86.zip'},
    {'windows','arm64','win-arm64.zip'},
    {'linux','amd64','linux-x64.tar.gz'},
    {'darwin','arm64','darwin-arm64.tar.gz'},
}
for _, case in ipairs(cases) do
    test('package '..case[1]..'/'..case[2], function()
        RUNTIME={osType=case[1],archType=case[2]}
        local filename='node-v20.16.0-'..case[3]
        local hash=string.rep('a',64)
        state.response={status_code=200,body=hash..'  '..filename..'\n'}
        local result=PLUGIN:PreInstall({version='20.16.0'})
        assert(result.url:sub(-#filename)==filename,result.url)
        assert(result.sha256==hash,'checksum missing')
    end)
end
test('missing architecture',function()
    RUNTIME={osType='windows'}
    expect_error(function() PLUGIN:PreInstall({version='20.16.0'}) end,'architecture')
    assert(state.requests==0)
end)
test('missing package',function()
    RUNTIME={osType='windows',archType='arm64'}
    state.response={status_code=200,body=string.rep('a',64)..'  node-v20.16.0-win-x64.zip\n'}
    expect_error(function() PLUGIN:PreInstall({version='20.16.0'}) end,'node-v20.16.0-win-arm64.zip')
end)
print(state.passed..' passed, '..state.failed..' failed')
assert(state.failed==0)
