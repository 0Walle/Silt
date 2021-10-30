local element = require 'element'

local inline_processors = {}

function run_inline_code(silt, children, s)
	local text_node_start = 1

	while true do
		local start, next, match = string.find(s, "(`+)", text_node_start)
		if match == nil then break end
		local end_, _, _ = string.find(s, match, next + 1, true)
		if end_ == nil then break end

		local first = s:sub(text_node_start, start-1)
		local code = s:sub(next + 1, end_ - 1)

		code = code:gsub('<', '&lt;')
		code = code:gsub('>', '&gt;')

		if #first > 0 then table.insert(children, first) end
		table.insert(children, element.from { tag = 'code', children = { code } } )

		text_node_start = end_ + #match
	end

	local first = s:sub(text_node_start)
	if #first > 0 then table.insert(children, first) end
end

function run_inline_link(silt, children, s)

	local search_start = 1

	while true do
		local before, content, href, end_ = find_link_pattern(s, search_start)

		if not before then break end

		local is_image = false
		if (before > 0 and s:sub(before, before) == '!') then
			is_image = true
			before = before - 1
		end

		local first = s:sub(search_start, before)
		if #first > 0 then table.insert(children, unescape(first)) end

		content = unescape(content)

		if is_image then
			table.insert(children, element.from {
				tag = 'img',
				attr = { src = href, alt = content },
				children = { }
			})
		else
			table.insert(children, element.from {
				tag = 'a',
				attr = { href = href },
				children = { content }
			})
		end
		
		search_start = end_
	end

	local first = s:sub(search_start)
	if #first > 0 then table.insert(children, first) end
end

function run_inline_emphasis(silt, children, s)

	local search_start = 1

	while true do
		local before, tag, content, next = find_emphasis_pattern(s, search_start)

		if not tag then break end

		local first = s:sub(search_start, before)
		if #first > 0 then table.insert(children, unescape(first)) end

		content = unescape(content)

		if #tag == 1 then
			table.insert(children, element.from {
				tag = 'em',
				children = { content }
			})
		elseif #tag == 2 then
			table.insert(children, element.from {
				tag = 'strong',
				children = { content }
			})
		elseif #tag == 3 then
			table.insert(children, element.from {
				tag = 'strong',
				children = {
					element.from { tag='em', children={ content } }
				}
			})
		end
		
		search_start = next

	end

	local first = s:sub(search_start)
	if #first > 0 then table.insert(children, first) end
end

function inline_processors.init(silt, config)
	silt.default_inline_processors = {
		run_inline_code,
		run_inline_link,
		run_inline_emphasis
	}
end

return inline_processors