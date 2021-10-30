local element = {}

function element.to_html(el)
	return element_to_html(el)
end

function element.new(tag)
	local a = {
		tag = tag,
		attr = {},
		children = {}
	}
	setmetatable(a, { __index = element })
	return a
end

function element.from(a)
	if a.attr == nil then a.attr = { } end
	if a.children == nil then a.children = {} end
	setmetatable(a, { __index = element })
	return a
end

function element:append(node)
	table.insert(self.children, node)
	return self
end

return element