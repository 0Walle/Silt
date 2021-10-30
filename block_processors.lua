local element = require 'element'

local block_processors = {}

function test_hash_header(silt, parent, block)
	local start, level, header = block:match("()(#+)([^\n]+)")
	if start ~= nil then
		local start_of_line = block:sub(start-1, start):gsub('\n', ''):sub(1, 1)

		if start_of_line == '#' then return true end
	end

	return false
end

function run_hash_header(silt, parent, block, blocks)
	local start, level, header, end_ = block:match("()(#+)([^\n]+)()")
	
	if start ~= 1 then
		table.insert(blocks, 1, block:sub(start))
		table.insert(blocks, 1, block:sub(1, start - 1))
		return
	end

	level = #level
	header = header:gsub('^%s+', '')

	local attr = {}
	local id = header:match('^{([%w-]+)}')

	header = header:gsub('^{[%w-]+}%s*', '', 1)

	if id then
		attr['id'] = id
	end

	table.insert(parent, element.from {
		tag = 'h' .. level,
		attr = attr,
		children = { header }
	})
	
	if end_ then
		table.insert(blocks, 1, block:sub(end_ + 1))
	end
end

function run_paragraph(silt, parent, block, blocks)
	block = block:gsub('%s+$', '')

	if #block == 0 then return end

	table.insert(parent, element.from {
		tag = 'p',
		children = { block }
	})
end

function test_block_quote(silt, parent, block)
	local match = block:match("^(>%s*)")
	if match ~= nil then
		return true
	end

	return false
end

function run_block_quote(silt, parent, block, blocks)
	local new_blocks = {}

	local lines = split_lines(block)
	for i,s in ipairs(lines) do
		lines[i] = s:gsub('^>%s*', '')
	end

	block = table.concat(lines, "\n")

	local start = 1
	for index in string.gmatch(block, "()\n\n") do
		local k = block:sub(start, index)
		start = index + 1
		table.insert(new_blocks, k)
	end

	if start == 1 then
		table.insert(new_blocks, block:sub(start))
	end

	local new_parent = {}
	silt.parse_blocks(new_parent, new_blocks)

	local blockquote = element.from {
		tag = 'blockquote',
		children = new_parent
	}

	table.insert(parent, blockquote)
end

function test_code_block(silt, parent, block)
	local match = block:match("^```")
	if match ~= nil then
		return true
	end
	return false
end

function run_code_block(silt, parent, block, blocks)
	local i = 1
	if block:match('```\n*$') == nil then
		while true do
			if blocks[i] == nil then break end

			local match = blocks[i]:match("\n%s*```") ~= nil

			block = block .. '\n' .. blocks[i]
			
			i = i + 1

			if match then break end
		end
	end

	local class = block:match('^```([^\n]*)')

	if class:match("^{") then
		class = assert(load( 'return (' .. class .. ')'))()
	end

	local start, _ = block:find('\n')
	local end_, _ = block:find("\n%s*```\n+")

	local code = block:sub(start+1, end_)

	for _ = 1, i-1 do
		table.remove(blocks, 1)
	end

	local el = element.from {
		tag = 'pre',
		children = {
			element.from {
				tag = 'code',
				children = { code }
			}
		}
	}

	if type(class) == 'string' then
		el.children[1].attr = { class = class }
	else
		el.children[1].attr = class
	end

	table.insert(parent, el)
end

function test_ulist_block(silt, parent, block)
	local match = block:match("^[-*+] ")
	if match ~= nil then return true end

	match = block:match("\n[-*+] ")
	if match ~= nil then return true end

	return false
end

function run_ulist_block(silt, parent, block, blocks)
	local match = block:match("^[-*+] ")

	if not match then
		local start = block:find("\n[-*+] ")
		table.insert(blocks, 1, block:sub(start + 1))
		table.insert(blocks, 1, block:sub(1, start - 1))
		return
	end

	while true do
		if blocks[1] == nil then break end
		if not test_ulist_block(silt, parent, blocks[1]) then break end
		block = block .. '\n\n' .. blocks[1]
		table.remove(blocks, 1)
	end

	local items = {}

	block = '\n' .. block

	local search_start = 1

	while true  do
		local start, next = string.find(block, "\n[-*+] ", search_start)

		if not start then break end

		local end_, _ = string.find(block, "\n[-*+] ", next)

		if not end_ then
			end_ = #block - 1
		end

		table.insert(items, block:sub(start + 3, end_ - 1))
		
		search_start = end_
		
	end

	local children = {}
	for i, v in ipairs(items) do
		local result = remove_indent_and_parse_block(silt, '    ', v)

		table.insert(children, element.from {
			tag = 'li',
			children = result
		})
	end

	table.insert(parent, element.from {
		tag = 'ul',
		children = children
	})
end

function remove_indent_and_parse_block(silt, indent, block)
	local new_blocks = {}

	local lines = split_lines(block)

	for i,s in ipairs(lines) do
		lines[i] = s:gsub('^' .. indent, '')
	end

	block = table.concat(lines, "\n")

	local new_parent = {}

	new_blocks = split_blocks(block .. '\n\n')

	silt.parse_blocks(new_parent, new_blocks)

	return new_parent
end

function test_hr_block(silt, parent, block)
	local match = block:match("^([*-=])%1%1")
	
	if match == nil then return false end

	return true
end

function run_hr_block(silt, parent, block, blocks)

	table.insert(parent, element.new('hr'))
end

function block_processors.init(silt, config)
	silt.default_block_processors = {
		{ test = test_code_block, run = run_code_block },
		{ test = test_hash_header, run = run_hash_header },
		{ test = test_block_quote, run = run_block_quote },
		{ test = test_ulist_block, run = run_ulist_block },
		{ test = test_hr_block, run = run_hr_block },
		{ test = function() return true end, run = run_paragraph }
	}
end

return block_processors