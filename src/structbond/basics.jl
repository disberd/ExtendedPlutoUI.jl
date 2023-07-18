
import REPL: fielddoc
using HypertextLiteral
import PlutoUI.Experimental: wrapped
using PlutoUI: combine

# Extract CSS that will be used in internal functions
const CSS_PARTS = map(readdir(joinpath(@__DIR__, "css"))) do file
	name = replace(file, r"\.[\w]+$" => "") |> Symbol
	path = joinpath(@__DIR__, "css", file)
	name => read(path, String)
end |> NamedTuple

# Extract JS code that will be used in funtctions
const JS_PARTS = open(joinpath(@__DIR__, "js/code_parts.js"), "r") do file
    code_parts = []
    readuntil(file, "// NEW BLOCK:")
    while !eof(file)
        name = readline(file) |> strip |> Symbol
        code = readuntil(file, "// NEW BLOCK:") |> strip |> HypertextLiteral.JavaScript
        push!(code_parts, name => code) 
    end
	code_parts
end |> NamedTuple

# StructBond Helpers #
## Structs ##
struct NotDefined end

## Field Functions ##

### Description ###
# This is a wrapper to extract eventual documentation strings from struct fields
_fielddoc(s,f) = try
	fielddoc(s,f)
catch
	nothing
end

# Default implementation to be overrided for specific types and fields in order to provide custom descriptions
function fielddescription(::Type, ::Val)
	@nospecialize
	return NotDefined()
end

function fielddescription(s::Type, f::Symbol)
	@nospecialize
	@assert hasfield(s, f) "The structure $s has no field $f"
	# We check if the structure has a specific method for the field
	out = fielddescription(s, Val(f))
	out isa NotDefined || return out
	# Now we try with the docstring of the field
	out = _fielddoc(s, f)
	# When fielddoc doesn't find a specific field docstring (even when called with non-existing fields), it returns a standard markdown that lists the fields of the structure, se we test for a very weird symbol name to check if the returned value is actually coming from a docstring
	out == _fielddoc(s, :__Very_Long_Nonexisting_Field__) || return out
	# Lastly, we just give the name of the field if all else failed
	out = string(f)
end

### Bond ###

# Default implementation to be overrided for specific types and fields in order to provide custom Bond
function fieldbond(::Type, ::Val)
	@nospecialize
	return NotDefined()
end

### HTML ###

# Default implementation to be overrided for specific types and fields in order to provide custom Bond
function fieldhtml(::Type, ::Val)
	@nospecialize
	return NotDefined()
end

## Struct Functions ##

### Description ###

# Override the description of a Type
typedescription(T::Type) = string(Base.nameof(T))

### Bond ###

# This function has to be overwritten if a custom show method for a Type is intended when the type is shown as a filed of a BondTable
typeasfield(T::Type) = NotDefined()

# Basic function that is called for extracting the bond for a given field of a struct
function fieldbond(s::Type, f::Symbol)
	@nospecialize
	@assert hasfield(s, f) "The structure $s has no field $f"
	Mod = @__MODULE__
	# We check if the structure has a specific method for the field
	out = fieldbond(s, Val(f))
	out isa NotDefined || return out
	# If we reach this point it means that no custom method was defined for the bond value of this field
	# We try to see if the type has a custom implementation when shown as field
	ft = fieldtype(s,f)
	out = typeasfield(ft)
	out isa NotDefined && error("`$(Mod).fieldbond` has no custom method for field ($f::$ft) of type $s and `$(Mod).typeasfield` has no custom method for type $ft.\n
	Please add one or the other using `@addfieldsbond` or `@addtypeasfield`")
	return out
end

### HTML ###

# This function will be called for extracting the HTML for displaying a given field of a Type inside a BondTable
# It defaults to just creating a description from `fielddescription` and a bond from `fieldbond`
function fieldhtml(s::Type, f::Symbol)
	@nospecialize
	@assert hasfield(s, f) "The structure $s has no field $f"
	# We check if the structure has a specific method for the field
	out = fieldhtml(s, Val(f))
	out isa NotDefined || return out
	# Now we try with the docstring of the field
	out = wrapped() do Child
		@htl("""
		<field-html class='$f'>
			<field-description class='$f' title="This value is associated to field `$f`">$(fielddescription(s, f))</field-description>
			<field-bond class='$f'>$(Child(fieldbond(s, f)))</field-bond>
		</field-html>
		<style>
		$(CSS_PARTS.fieldhtml)
		</style>
		""")
	end
	return out
end

function typehtml(T::Type; description = typedescription(T))
	inner_bond = combine() do Child
		@htl """
		$([
			Child(string(name), fieldhtml(T, name))
			for name in fieldnames(T) if !Base.isgensym(name)
		])
		"""
	end
	ToggleReactiveBond(wrapped() do Child
		@htl("""
			$(Child(inner_bond))
		
	<script>
		const trc = currentScript.closest('togglereactive-container')
		const header = trc.firstElementChild
		const desc = header.querySelector('.description')
		desc.setAttribute('title', "This generates a struct of type `$(nameof(T))`")

		// add the collapse button
		const collapse_btn = html`<span class='collapse'>`
		header.insertAdjacentElement('afterbegin', collapse_btn)

		trc.collapse = () => {
  			trc.classList.toggle('collapsed')
		}

		collapse_btn.onclick = (e) => trc.collapse()
		
	</script>
		<style>
		$(CSS_PARTS.typehtml)
		</style>
		""")
	end; description)
end

### Constructor ###
typeconstructor(T::Type) = f(args) = T(;args...)
typeconstructor(::Type{<:NamedTuple}) = identity
