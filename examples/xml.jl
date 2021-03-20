using LightXML

xdoc = parse_file("examples/ex1.xml")

xroot = root(xdoc)

ces = collect(child_elements(xroot))  # get a list of all child elements
@assert length(ces) == 2

# if you know the child element tagname, you can instead get a list as
IRS = get_elements_by_tagname(xroot, "IRS")
CRS = get_elements_by_tagname(xroot, "CRS")
# or shorthand:
ces = xroot["IRS"]

e1 = ces[1]  # the first book element

# print the value of an attribute
code = attribute(e1, "code")
println(code)
# find the first title element under e1
t = find_element(e1, "price")
typeof(t)
println(t)
println(content(t))
# retrieve the value of lang attribute of t
a = attribute(t, "lang")  # a <- "en"
typeof(a)
# retrieve the text content of t
r = content(t)  # r <- "Everyday Italian"
free(xdoc)