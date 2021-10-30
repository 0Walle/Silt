local element = require 'element'
local block_processors = require 'block_processors'
local inline_processors = require 'inline_processors'

local silt = {}

default_elements_tree_processing = {
	['p'] = 'inline',
	['h1'] = 'inline',
	['h2'] = 'inline',
	['h3'] = 'inline',
	['h4'] = 'inline',
	['h5'] = 'inline',
	['h6'] = 'inline',
	['blockquote'] = 'block',
	['ul'] = 'block',
	['li'] = 'block',
}

function silt.init(input_file, config)

	silt.config = config

	silt.config['--output'] = silt.config['-o']

	silt.default_block_processors = {}
	silt.default_inline_processors = {}

	block_processors.init(silt, config)
	inline_processors.init(silt, config)
end

function silt.preprocess(text)
	text = text.gsub(text, '\r\n', '\n')
	text = text.gsub(text, '\r', '\n')
	text = text .. '\n\n'

	text = text.gsub(text, '\t', '    ')

	return text
end

function silt.parse_blocks(parent, blocks)
	while #blocks > 0 do
		local block = table.remove(blocks, 1)
		for _, processor in ipairs(silt.default_block_processors) do
			if processor.test(silt, parent, block) then
				processor.run(silt, parent, block, blocks)
				break
			end
		end
	end
end

function silt.process_blocks(parent, blocks)
	silt.parse_blocks(parent, blocks)

	local tree = element.from {
		tag = 'body',
		children = parent
	}

	return tree
end

function silt.process_tree(root)
	root = process_tree(root)

	return root.children
end

function process_tree(root)
	for k, v in pairs(root.children) do
		local mode = default_elements_tree_processing[v.tag]
		if mode == 'inline' then
			root.children[k] = process_inline(root, v)
		elseif mode == 'block' then
			root.children[k] = process_tree(v)
		end
	end

	return root
end

function process_inline(parent, el)
	for _, processor in ipairs(silt.default_inline_processors) do
		local new_children = {}

		for _, v in pairs(el.children) do
			if type(v) == 'string' then
				processor(silt, new_children, v)
			else
				table.insert(new_children, v)
			end
		end

		el.children = new_children
	end

	return el
end

function silt.postprocess(html)
	return [[<html>
	<head>
		<meta charset="utf8">
	</head>
	<body class="theme-dark">
	]] .. html .. [[
	</body>
	</html>]]
end

function silt.output_path(output_path)
	if silt.config['--output'] then
		return silt.config['--output']
	end

	return output_path
end

return silt