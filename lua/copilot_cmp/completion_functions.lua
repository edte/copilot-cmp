local format = require("copilot_cmp.format")

local methods = {
  opts = {
    fix_pairs = true,
  },
}

methods.getCompletionsCycling = function(self, params, callback)
  local respond_callback = function(err, response)
    if err or not response or not response.completions then
      return callback({ isIncomplete = false, items = {} })
    end

    local items = vim.tbl_map(function(item)
      return format.format_item(item, params.context, methods.opts)
    end, vim.tbl_values(response.completions))

    return callback({
      isIncomplete = false,
      items = items,
    })
  end

  get_completions_cycling(self.client, get_doc_params(), respond_callback)
  return callback({ isIncomplete = true, items = {} })
end

methods.init = function(completion_method, opts)
  methods.opts.fix_pairs = opts.fix_pairs
  return methods[completion_method]
end

function get_doc_params(overrides)
  overrides = overrides or {}

  local params = vim.tbl_extend("keep", {
    doc = vim.tbl_extend("force", get_doc(), overrides.doc or {}),
  }, overrides)
  params.textDocument = {
    uri = params.doc.uri,
    version = params.doc.version,
    relativePath = params.doc.relativePath,
  }
  params.position = params.doc.position

  return params
end

function get_completions_cycling(client, params, callback)
  return request(client, "getCompletionsCycling", params, callback)
end

---@param callback? fun(err: any|nil, data: table, ctx: table): nil
---@return any|nil err
---@return table data
---@return table ctx
function request(client, method, params, callback)
  -- hack to convert empty table to json object,
  -- empty table is convert to json array by default.
  params._ = true

  local bufnr = params.bufnr
  params.bufnr = nil

  if callback then
    return client.request(method, params, callback, bufnr)
  end

  local co = coroutine.running()
  client.request(method, params, function(err, data, ctx)
    coroutine.resume(co, err, data, ctx)
  end, bufnr)
  return coroutine.yield()
end

function get_doc()
  local absolute = vim.api.nvim_buf_get_name(0)
  local params = vim.lsp.util.make_position_params(0, "utf-16") -- copilot server uses utf-16
  local doc = {
    uri = params.textDocument.uri,
    version = vim.api.nvim_buf_get_var(0, "changedtick"),
    relativePath = relative_path(absolute),
    insertSpaces = vim.o.expandtab,
    tabSize = vim.fn.shiftwidth(),
    indentSize = vim.fn.shiftwidth(),
    position = params.position,
  }

  return doc
end

function relative_path(absolute)
  local relative = vim.fn.fnamemodify(absolute, ":.")
  if string.sub(relative, 0, 1) == "/" then
    return vim.fn.fnamemodify(absolute, ":t")
  end
  return relative
end

return methods
