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
    doc = vim.tbl_extend("force", M.get_doc(), overrides.doc or {}),
  }, overrides)
  params.textDocument = {
    uri = params.doc.uri,
    version = params.doc.version,
    relativePath = params.doc.relativePath,
  }
  params.position = params.doc.position

  return params
end

---@param ctx copilot_suggestion_context
local function get_suggestions_cycling_callback(ctx, err, data)
  local callbacks = ctx.cycling_callbacks or {}
  ctx.cycling_callbacks = nil

  if err then
    print(err)
    return
  end

  if not ctx.suggestions then
    return
  end

  local seen = {}

  for _, suggestion in ipairs(ctx.suggestions) do
    seen[suggestion.text] = true
  end

  for _, suggestion in ipairs(data.completions or {}) do
    if not seen[suggestion.text] then
      table.insert(ctx.suggestions, suggestion)
      seen[suggestion.text] = true
    end
  end

  for _, callback in ipairs(callbacks) do
    callback(ctx)
  end
end

return methods
