--  Copyright (C) 2009 Lingyun Wu
--  This file may be distributed and/or modified under the
--  conditions of the LaTeX Project Public License, either version 1.3
--  of this license or (at your option) any later version.
--  The latest version of this license is in
--    http://www.latex-project.org/lppl.txt
--  and version 1.3 or later is part of all distributions of LaTeX
--  version 2005/12/01 or later.


-- global settings
settings = {
	name = "zhfd",
	version = "v1.0",
	date = "2009/09/23",
	slant = "sl",
}

-- expand the variables in string
function expand(s, t)
	return (string.gsub(s, "%$(%w+)", t or settings))
end
expand_path = expand

-- replace default io.open
do
	local open = io.open
	io.open = function(f, m) return open(expand_path(f), m) end
end

-- fd file template
fdfile = [[
% This is the file $fdprelower$fdname.fd of the CJK package
%   for using Asian logographs (Chinese/Japanese/Korean) with LaTeX2e
%
% automatically generated by $name $version

\def\fileversion{4.8.2}
\def\filedate{$date}
\ProvidesFile{$fdprelower$fdname.fd}[\filedate\space\fileversion]

% Chinese characters
%
% character set: $encoding
% font encoding: CJK ($encoding)

\DeclareFontFamily{$fdpre}{$fdname}{\hyphenchar \font\m@ne}

\DeclareFontShape{$fdpre}{$fdname}{m}{n}{<-> CJK * $prefix$cjkname}{\CJKnormal}
\DeclareFontShape{$fdpre}{$fdname}{b}{n}{<-> CJKb * $prefix$cjkname}{\CJKbold}
\DeclareFontShape{$fdpre}{$fdname}{bx}{n}{<-> CJKb * $prefix$cjkname}{\CJKbold}
\DeclareFontShape{$fdpre}{$fdname}{m}{it}{<-> CJK * $prefix$cjkname$slant}{\CJKnormal}
\DeclareFontShape{$fdpre}{$fdname}{b}{it}{<-> CJKb * $prefix$cjkname$slant}{\CJKbold}
\DeclareFontShape{$fdpre}{$fdname}{bx}{it}{<-> CJKb * $prefix$cjkname$slant}{\CJKbold}
\DeclareFontShape{$fdpre}{$fdname}{m}{sl}{<-> CJK * $prefix$cjkname$slant}{\CJKnormal}
\DeclareFontShape{$fdpre}{$fdname}{b}{sl}{<-> CJKb * $prefix$cjkname$slant}{\CJKbold}
\DeclareFontShape{$fdpre}{$fdname}{bx}{sl}{<-> CJKb * $prefix$cjkname$slant}{\CJKbold}

\endinput
]]

function generate_fd (encoding, fdpre, fdname, prefix, cjkname)
	settings.encoding = encoding
	settings.fdpre = fdpre
	settings.fdprelower = string.lower(fdpre)
	settings.fdname = fdname
	settings.prefix = prefix
	settings.cjkname = cjkname
	local f = io.open([[$fdprelower$fdname.fd]], "w")
	if f then
		f:write(expand(fdfile))
		io.close(f)
	end
end

generate_fd("GBK", "C19", "song", "gbk", "song")
generate_fd("GBK", "C19", "hei",  "gbk", "hei")
generate_fd("GBK", "C19", "kai",  "gbk", "kai")
generate_fd("GBK", "C19", "fs",   "gbk", "fs")
generate_fd("GBK", "C19", "li",   "gbk", "li")
generate_fd("GBK", "C19", "you",  "gbk", "you")

generate_fd("UTF8", "C70", "song", "uni", "song")
generate_fd("UTF8", "C70", "hei",  "uni", "hei")
generate_fd("UTF8", "C70", "kai",  "uni", "kai")
generate_fd("UTF8", "C70", "fs",   "uni", "fs")
generate_fd("UTF8", "C70", "li",   "uni", "li")
generate_fd("UTF8", "C70", "you",  "uni", "you")

