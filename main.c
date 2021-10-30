#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lib/lua/lua.h"
#include "lib/lua/lauxlib.h"
#include "lib/lua/lualib.h"

int element_to_html(lua_State *L) {
	luaL_checktype(L, -1, LUA_TTABLE);

	int element = lua_gettop(L);
	
	lua_getfield(L, element, "tag");
	size_t tag_name_len = 0;
	char const *tag_name = lua_tolstring(L, -1, &tag_name_len);
	lua_pop(L, 1);

	int typeof_attr = lua_getfield(L, element, "attr");
	int attr_ = lua_gettop(L);

	if (tag_name != NULL) {
		luaL_Buffer b;
		luaL_buffinit(L, &b);

		luaL_addchar(&b, '<');
		luaL_addlstring(&b, tag_name, tag_name_len);

		if (typeof_attr == LUA_TTABLE) {
			lua_pushnil(L);
			while (lua_next(L, attr_) != 0) {
				lua_pushnil(L);
				lua_copy(L, -3, -1);
				luaL_addchar(&b, ' ');
				luaL_addvalue(&b);
				luaL_addchar(&b, '=');
				luaL_addchar(&b, '"');
				luaL_addvalue(&b);
				luaL_addchar(&b, '"');
			}
		}

		luaL_addchar(&b, '>');
		luaL_pushresult(&b);

		luaL_buffinit(L, &b);
		luaL_addchar(&b, '<');
		luaL_addchar(&b, '/');
		luaL_addlstring(&b, tag_name, tag_name_len);
		luaL_addchar(&b, '>');
		luaL_pushresult(&b);
	}

	if (tag_name != NULL) {
		lua_remove(L, -3);
	} else {
		lua_remove(L, -1);
	}


	lua_getfield(L, element, "children");
	int children = lua_gettop(L);
	int len = lua_rawlen(L, -1);

	if (lua_isnil(L, -1)) {
		children = element;
		len = lua_rawlen(L, -2);
	}

	for (int i = 1; i < len+1; ++i) {
		int typeof_child = lua_rawgeti(L, children, i);
		if (typeof_child == LUA_TSTRING) {

		} else {
			element_to_html(L);

			lua_remove(L, -2);
		}
	}

	lua_concat(L, len);

	lua_remove(L, -2);

	if (tag_name != NULL) {
		lua_rotate(L, -2, 1);
		lua_concat(L, 3);
	}

	return 1;
}

int split_lines(lua_State *L) {
	char *string = (char*)luaL_checkstring(L, 1);

	char *reader = string;
	char *start = string;
	int i = 1;


	lua_newtable(L);

	for (;;) {
		if (*reader == '\n') {
			lua_pushlstring(L, start, reader - start);
			lua_rawseti(L, -2, i);
			start = reader+1;
			i += 1;
		}

		if (*reader == '\0') {
			lua_pushlstring(L, start, reader - start);
			lua_rawseti(L, -2, i);
			break;
		}
		
		reader += 1;
	}

	return 1;
}

int split_blocks(lua_State *L) {
	char *string = (char*)luaL_checkstring(L, 1);

	char *reader = string;
	char *start = string;
	int block_len = 0;
	int i = 1;


	lua_newtable(L);

	for (;;) {
		if (reader[0] == '\0') break;

		if (reader[0] == '\n' && reader[1] == '\n') {
			
			while (reader[0] == '\n') {
				reader += 1;
			}

			block_len = reader - start;

			lua_pushlstring(L, start, block_len);
			lua_seti(L, -2, i);
			i += 1;

			start = reader;

			// reader[-1] = '\0';
		}

		reader += 1;
	}

	return 1;
}

int find_link_pattern(lua_State *L) {
	char *string = (char*)luaL_checkstring(L, 1);
	int n = lua_gettop(L);

	int start = 0;
	if (n == 2) {
		start = luaL_checkinteger(L, 2);
		start -= 1;
	}

	char *reader = string + start;

	for (;;) {
		if (*reader == '\0') {
			luaL_pushfail(L);
			return 1;
		}

		if (*reader == '\\') {
			reader += 2;
			continue;
		}

		if (*reader == '[') {
			int text_start = reader - string;
			lua_pushinteger(L, text_start);

			while (*reader != ']') {
				if (*reader == '\\') reader += 1;
				reader += 1;
			}

			reader += 1;

			lua_pushlstring(L, string + text_start + 1, (int)(reader - string - text_start - 2));

			if (*reader != '(') {
				lua_pop(L, 2);
				continue;
			}

			text_start = reader - string;
			reader += 1;

			while (*reader != ')') {
				if (*reader == '\\') reader += 1;
				reader += 1;
			}
			reader += 1;

			lua_pushlstring(L, string + text_start + 1, reader - string - text_start - 2);

			lua_pushinteger(L, reader - string + 1);

			return 4;
		}
		
		reader += 1;
	}

	luaL_pushfail(L);
	return 1;
}

int find_emphasis_pattern(lua_State *L) {
	size_t string_size;
	char *string = (char*)luaL_checklstring(L, 1, &string_size);
	int n = lua_gettop(L);

	int start = 0;
	if (n == 2) {
		start = luaL_checkinteger(L, 2);
		start -= 1;
	}

	char *reader = string + start;

	for (;;) {
		if (reader >= string + string_size) {
			luaL_pushfail(L);
			return 1;
		}

		if (*reader == '\\') {
			reader += 2;
			continue;
		}

		char *match;
		int match_len;

		if (*reader == '*' || *reader == '_') {

			if (reader[1] == ' ') {
				reader += 1;
				continue;
			}

			match = reader;
			match_len = 0;

			while (*reader == '*' || *reader == '_') {
				reader += 1;
				match_len += 1;
			}

			if (match_len > 3) {
				reader += 1;
				continue;
			}

			loop:
			while (*reader != match[0]) {

				if (reader >= string + string_size) {
					luaL_pushfail(L);
					return 1;
				}


				if (*reader == '\\') reader += 1;
				if (*reader == ' ') reader += 1;
				reader += 1;
			}

			if (match_len == 2 && reader[1] != match[1]) {
				reader += 1;
				goto loop;
			}

			if (match_len == 3 && reader[2] != match[2]) {
				reader += 1;
				goto loop;
			}

			lua_pushinteger(L, match - string);
			lua_pushlstring(L, match, match_len);
			lua_pushlstring(L, match+match_len, reader - match - match_len);
			lua_pushinteger(L, reader - string + match_len + 1);
			return 4;

		}
		
		reader += 1;
	}

	luaL_pushfail(L);
	return 1;
}

int string_unescape(lua_State *L) {
	size_t string_size;
	char *string = (char*)luaL_checklstring(L, 1, &string_size);
	char *reader = string;

	luaL_Buffer b;
	luaL_buffinit(L, &b);

	for (;;) {
		if (reader >= string + string_size) {
			break;
		}

		if (*reader == '\\') {
			reader += 1;
			luaL_addchar(&b, *reader);
			reader += 1;
			continue;
		}

		luaL_addchar(&b, *reader);
		reader += 1;
	}

	luaL_pushresult(&b);

	return 1;
}

int parse_args(lua_State *L, int argc, char const *argv[]) {
	if (argc < 2) { return 1; }

	lua_pushstring(L, argv[1]);

	lua_newtable(L);

	int parse_index = 2;

	while (parse_index < argc) {
		if (argv[parse_index][0] != '-') return parse_index;
		if (parse_index + 1 >= argc) return parse_index;

		lua_pushstring(L, argv[parse_index]);
		lua_pushstring(L, argv[parse_index+1]);
		lua_settable(L, -3);

		parse_index += 2;
	}

	return 0;
}

int main (int argc, char const *argv[]) {
	int error;
	lua_State *L = luaL_newstate();
	luaL_openlibs(L);

	lua_pushcfunction(L, split_lines);
	lua_setglobal(L, "split_lines");

	lua_pushcfunction(L, split_blocks);
	lua_setglobal(L, "split_blocks");

	lua_pushcfunction(L, element_to_html);
	lua_setglobal(L, "element_to_html");

	lua_pushcfunction(L, find_link_pattern);
	lua_setglobal(L, "find_link_pattern");

	lua_pushcfunction(L, find_emphasis_pattern);
	lua_setglobal(L, "find_emphasis_pattern");

	lua_pushcfunction(L, string_unescape);
	lua_setglobal(L, "unescape");

	error = luaL_dofile(L, "silt.lua");

	if (error) {
		fprintf(stderr, "%s", lua_tostring(L, -1));
		lua_pop(L, 1);
		return 1;
	}

	int silt_i = lua_gettop(L);

	lua_getfield(L, silt_i, "init");

	int arg_err;
	if ((arg_err = parse_args(L, argc, argv))) {
		if (arg_err == 1) {
			printf("No input file argument\n");
		} else {
			printf("Error parsing argument at position %i\n", arg_err - 1);
		}
		return 1;
	}
	
	lua_call(L, 2, 0);

	char *filename = strrchr(argv[1], '/');

	if (filename == NULL) {
		filename = (char*)argv[1];
	}

	char *ext = strrchr(filename, '.');
	int input_file_path_len = strlen(argv[1]);

	FILE *f = fopen(argv[1], "rb");

	fseek(f, 0, SEEK_END);
	long fsize = ftell(f);
	fseek(f, 0, SEEK_SET);

	char *file_contents = malloc(fsize+256);
	fread(file_contents, 1, fsize, f);
	fclose(f);

	file_contents[fsize] = 0;

	lua_getfield(L, silt_i, "preprocess");
	lua_pushlstring(L, file_contents, fsize);

	free(file_contents);

	lua_call(L, 1, 1);

	if (lua_tolstring(L, -1, NULL) == NULL) {
		return luaL_error(L, "Preprocess step result is not a string");
	}

	lua_getglobal(L, "split_blocks");
	lua_rotate(L, -2, 1);
	lua_call(L, 1, 1);

	lua_getfield(L, silt_i, "process_blocks");
	lua_newtable(L);
	lua_rotate(L, -3, -1);
	lua_call(L, 2, 1);

	lua_getfield(L, silt_i, "process_tree");
	lua_rotate(L, -2, 1);
	lua_call(L, 1, 1);

	element_to_html(L);

	lua_getfield(L, silt_i, "postprocess");
	lua_rotate(L, -2, 1);
	lua_call(L, 1, 1);

	size_t result_html_size;
	char *result_html = (char*)lua_tolstring(L, -1, &result_html_size);


	char output_file[input_file_path_len + 5];
	int ext_len = strlen(ext);
	sprintf(output_file, "%.*s.html", input_file_path_len - ext_len, argv[1]);

	lua_getfield(L, silt_i, "output_path");
	lua_pushstring(L, output_file);
	lua_call(L, 1, 1);

	char *output_file_final = (char*)lua_tolstring(L, -1, NULL);

	f = fopen(output_file_final, "wb");
	fwrite(result_html, 1, result_html_size, f);
	fclose(f);
	
	lua_close(L);
	return 0;
}