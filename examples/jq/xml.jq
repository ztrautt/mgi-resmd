import "textwrap" as textwrap;

def context: {
    "indent": (($config|.xml.indent) // 2)|tonumber,
    "pad":    (($config|.xml.pad) // 0)|tonumber,
    "max_line_width":  (($config|.xml.max_line_width) // 75)|tonumber,
    "min_line_width":  (($config|.xml.max_line_width) // 30)|tonumber,
    "text_packing":  (($config|.xml.text_packing) // "compact"),
    "style":  (($config|.xml.style) // "pretty")
};

def _attribute(name; value; nsinfo): 
   { "name": name,
     "value": value,
     "ns": nsinfo };
def _tons: 
   (objects | { prefix, namespace }),
   (strings | { namespace: . }),
   (arrays  | { prefix: .[0], namespace: .[1] });


# Create an XML attribute object
# @arg name string:   the local name of the element; this can include
#                     a prefix which will override the prefix given
#                     via the namespace argument
# @arg value any:     the value to give to the element; this will be 
#                     converted to a string when printed via print
# @arg ns (string,object,array):  namespace information: if a string, it is 
#                     taken to be the namespace URI for the attribute; 
#                     If an object, the "prefix" property is the prefix to 
#                     use, and the "namespace" property is the namespace URI;
#                     either property is optional.  If an array, the first
#                     item is assumed to be the prefix and the second, the
#                     namespace
def attribute(name; value): _attribute(name; value; {});
def attribute(name; value; ns): _attribute(name; value; ns|_tons);

def _element_content(children; attrs): {children: children, attrs: attrs};

def element_content(children): children |
    (strings | { "children": [.] }),
    (arrays | { "children": . }),
    (objects | { "children": .children, "attrs": .attrs });
def element_content(children; attrs): {
    "children": children | (
       (strings | [.]),
       (arrays | .),
       (objects | if .name then [.] else [] end)),
    "attrs": attrs | (
       (strings | [.]),
       (arrays | .),
       (objects | if .name then [.] else [] end)),
};


# Create an XML element object
# @arg name string:   the local name of the element; this can include
#                     a prefix which will override the prefix given
#                     via the namespace argument
# @arg ns (string,object,array):  namespace information: if a string, it is 
#                     taken to be the namespace URI for the attribute; 
#                     If an object, the "prefix" property is the prefix to 
#                     use, and the "namespace" property is the namespace URI;
#                     either property is optional.  If an array, the first
#                     item is assumed to be the prefix and the second, the
#                     namespace
def _element(name; nsinfo; content): { 
    "name": name,
    "ns": nsinfo,
    "content": content
};
def element(name): { "name": name, "content": { }};
def element(name; nsinfo): _element(name; nsinfo|_tons; {});
def element(name; nsinfo; content): 
    _element(name; nsinfo|_tons; content);

# Create an XML element object containing a single text element
# @arg name string:   the local name of the element; this can include
#                     a prefix which will override the prefix given
#                     via the namespace argument
# @arg value any:     the value to give to the element; this will be 
#                     converted to a string when printed via print
# @arg ns (string,object,array):  namespace information: if a string, it is 
#                     taken to be the namespace URI for the attribute; 
#                     If an object, the "prefix" property is the prefix to 
#                     use, and the "namespace" property is the namespace URI;
#                     either property is optional.  If an array, the first
#                     item is assumed to be the prefix and the second, the
#                     namespace
def text_element(name; value): element(name) + element_content(value);
def text_element(name; value; nsinfo): 
    element(name, nsinfo) + element_content(value);

# add an attribute to the input element and return the element
#
# @arg attribute object:  the attribute object to add
#
def add_attr2element(attribute):
    if has("content")|not then
        .["content"] = {}
    else . end |
    if .content|has("attrs")|not then
        .content["attrs"] = []
    else . end |
    .content.attrs += [attribute];

# add child--either a string or an element object--to the input element and 
# return the parent element
#
# @arg child object:  the attribute object to add
#
def add_child2element(child):
    if has("content")|not then
        .["content"] = {}
    else . end |
    if .content|has("children")|not then
        .content["children"] = []
    else . end |
    .content.children += [child];



def isstring: textwrap::isstring;

# format the given text for inclusion as the content for an element.  This 
# will fill the text to a minimum line width (controlled by the config 
# parameter xml.min_line_width) unless the config parameter text_packing is 
# set to "compact"; if compact packing is set, then the text is unchanged.  
#
# @arg indent integer:  the number of characters to indent the formatted text
#                         (if compact text packing is not in force).
def format_text(indent): 
    if (isstring|not) then error("filter format_text requires text input")
       else . end |
    context as $context |
    if ($context|.text_packing) == "compact" then 
     textwrap::fill($context|.max_line_width; indent; $context|.min_line_width)
    else . end;
def format_text: format_text(0);

def newprefix: 
    "ns"+ (values | map(select(test("^ns\\d+$"))) | 
                    map(.[2:]|tonumber) | max+1 | tostring);

def _determine_prefix(prefixes):
    if . == null then
        ""
    elif .prefix then
        .prefix + ":"
    elif .namespace then
        .namespace as $nsuri | 
        if (prefixes|has($nsuri)) then
            (prefixes|.[$nsuri]) + ":"
        else
            error("unmapped namespace: "+.namespace)
        end
    else
        ""
    end;
            
def _pack_recurse(width):
    if (.[-1]|length) > 0 then
        if ((.[0][-1]|length)+(.[-1][0]|length)+1) > width then
            # add a new line for the next attribute
            .[0] += [.[-1][0]] 
        else
            # append the next attribute to the current line
            .[0][-1] += " " + .[-1][0] 
        end | del(.[-1][0]) |
        _pack_recurse(width)
    else
        .
    end;
def _pack(width):
    [ .[0:1], .[1:] ] | _pack_recurse(width) | .[0];

def format_attribute(prefixes):
    if isstring then
        .
    elif (.name|contains(":")) then
        .name + "=\"" + .value + "\""
    else
        (.ns | _determine_prefix(prefixes)) as $pfx |
        $pfx + .name + "=\"" + .value + "\""
    end;

# format the attributes for insertion into an opening element tag.
# When many attributes are present, these can be wrapped onto separate lines.
# 
# @arg indent integer:    The indentation to use when wrapping the attributes
#                         onto multiple lines: all but the first line will be
#                         prepended by this number of spaces.  Normally, this 
#                         is equal to the length of the opening tag (i.e.
#                         "<elname ") plus the indentation in front of the 
#                         element.
# @arg prefixes object:   an object where the keys are namespace URIs and 
#                         the values are namespace prefixes in currently in 
#                         use.
# @return string    the attributes formatted into a string to be inserted into
#                   an opening tag.  It may contain embedded new lines for 
#                   pretty printing.
def format_attributes(indent; prefixes):
    context as $context | 
    map(format_attribute(prefixes)) | 
    if ($context|.style) == "pretty" then
        ($context|.max_line_width) as $usewidth |
        ($context|.min_line_width) as $minwidth |
        ($usewidth - indent) as $usewidth |
        (if $usewidth < $minwidth then $minwidth else $usewidth end) 
            as $usewidth |
        _pack($usewidth) | join("\n"+(" " * indent))
    else
        join(" ")
    end;

def _gather_new_namespaces:
    if .node.ns then
        if .node.ns.namespace then
            .node.ns.namespace as $nsuri |
            if (.prefixes|has($nsuri)|not) then
                if .node.ns.prefix then
                   .new += [[.node.ns.prefix, $nsuri]]
                else 
                   .new += [[(.prefixes|newprefix), $nsuri]]
                end |
                .prefixes[.new[-1][1]] = .new[-1][0] 
            elif .ns.prefix then 
                if .prefixes[$nsuri] != .ns.prefix then
                   .new += [[.node.ns.prefix, $nsuri]] |
                   .prefixes[.new[-1][1]] = .new[-1][0] 
                else empty end
            else . end
        else . end
     else . end |
     if .node.content.attrs then
         # node is an element with attributes; check its attributes

         # loop through the attributes and pull out any new namespaces.
         # reduce is used so that updates to .prefixes are seen through
         # subsequent iterations.
         reduce .node.content.attrs[] as $attr 
               (.; .node = $attr | _gather_new_namespaces)
     else 
         .
     end;

# return an prefixes object that is the given set of prefixes updated for 
# namespaces introduced by the input XML node.  The input can either be 
# an attribute node or an element node.
#
# @arg prefixes object:  the mapping of namespace URIs (i.e. the keys) to 
#                          associated prefixes (values). 
#
def new_namespaces(prefixes): 
    { "prefixes": prefixes, "node": ., "new": [] } |
    _gather_new_namespaces | .new;



def format_element(indent; prefixes):
    context as $context | 
    if .|has("hints") then
        ($context + .hints) as $context | .
    else . end |

    # determine what new namespaces we'll need to declare
    . as $el |
    { "node": ., "prefixes": prefixes, "new": [] } |
    _gather_new_namespaces | .new as $new | .prefixes as $prefixes | $el |

    # add any new namespace declarations as attributes
    reduce ($new|.[]) as $attr 
           (.; add_attr2element("xmlns:"+($attr|.[0]) + "=\"" +
                                ($attr|.[1])+"\"") ) |

    # determine the fully qualified element name
    (if (.name|contains(":")) then
        .name
     else 
        (.ns | _determine_prefix($prefixes)) + .name
     end) as $name | 

    # opening tag
    ((indent * " ") + "<" + $name) as $opentag | 

    # add attributes
    (if (.content.attrs|length) > 0 then ($opentag + " ") else $opentag end)
        as $opentag |
    (if (.content.attrs|length) > 0 then
        (.content.attrs | format_attributes(($opentag|length)+1; $prefixes)) 
    else "" end) as $atts | 

    if (.content.children|length) > 0 then
        ($opentag + $atts + ">") as $opentag |
        ("</" + $name + ">") as $closetag |
        ($context|.max_line_length) as $maxlen |
        ($context|.min_line_length) as $minlen |

        .content.children |
        if length == 1 and (.[0]|isstring) then
            # single text value
            if ($context|.value_pad) <= 0 or 
               (($context|.text_packing)=="pretty" and 
                (.[0]|length) < $maxlen-($opentag|length)-($closetag|length))
            then
                # short enough to fit in one line
                (if ($context|.value_pad) > 0 then
                    ($context|.value_pad) * " "
                 else 
                    ""
                 end) as $pad |

                # return as a single line
                $opentag + $pad + .[0] + $pad + $closetag

            else 
                # we will treat like multi-child content later
                .
            end
        else . end | 

        if (isstring|not) then
            ($context|.indent) as $step |
            (if $step < 0 then
                0
             else
                (indent + $step)
             end) as $subindent |

            [ $opentag ] + map(if (.|isstring) then
                                   format_text($subindent)
                               else 
                                   format_element($subindent; $prefixes)
                               end)
                         + [ $closetag ] | 

            if $step < 0 then
                join("")
            else 
                join("\n" + (indent * " "))
            end
        else . end
    else 
        $opentag + $atts + "/>"
    end;


    


             
