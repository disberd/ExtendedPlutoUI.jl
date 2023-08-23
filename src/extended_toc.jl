### A Pluto.jl notebook ###
# v0.19.27

#> custom_attrs = ["enable_hidden", "hide-enabled"]

using Markdown
using InteractiveUtils

# ╔═╡ 464fc674-5ed7-11ed-0aff-939456ebc5a8
begin
	using HypertextLiteral
	using PlutoUI
	using PlutoDevMacros.Script
end

# ╔═╡ 46520c1a-bbd8-46aa-95d9-bad3d220ee85
# ╠═╡ custom_attrs = ["gesu", "toc-collapsed"]
md"""
# Scripts
"""

# ╔═╡ 6fb280c9-996e-4e0b-beb4-72e4acc9dada
md"""
## Smooth Scroll
"""

# ╔═╡ 98191362-88d4-42f7-a3dc-d497b012b42c
md"""
Since v0.7.51 PlutoUI directly supports the smooth scrolling library in the TableOfContents, so we just take it from there.
"""

# ╔═╡ 3ea073ee-59d5-43a2-98c8-a309ce327418
_smooth_scroll = HTLScriptPart(@htl """
<script>
// Load the library for consistent smooth scrolling
const {default: scrollIntoView} = await import($(PlutoUI.TableOfContentsNotebook.smooth_scoll_lib_url))

function scroll_to(h, config = {
			behavior: 'smooth', 
			block: 'start',
		}) {
	scrollIntoView(h, config).then(() => 
			// sometimes it doesn't scroll to the right place
			// solution: try a second time!
			scrollIntoView(h, config)
	   )
	}
</script>
""");

# ╔═╡ aa74f780-96c5-4b91-9658-a34c8c3fcab9
md"""
## Basics
"""

# ╔═╡ a777b426-42e9-4c91-aebd-506388449042
_basics = HTLScript(
	@htl("""
	<script>
	let cell = currentScript.closest('pluto-cell')
	let pluto_actions = cell._internal_pluto_actions
	let toc = document.querySelector('nav.plutoui-toc')

	function getRow(el) {
		const row = el?.closest('.toc-row')
		return row
	}
		
	function get_link_id(el) {
		const row = getRow(el)
		if (_.isNil(row)) { return null }
		const a = row.querySelector('a')
		return a.href.slice(-36) // extract the last 36 characters, corresponding to the cell id
	}

	function getHeadingLevel(row) {
		const a = row.querySelector('a')
		// We return the link class without the first H
		return Number(a.classList[0].slice(1))
	}

	function generateChecker(selector) {
		switch (typeof selector) {
			case 'string':
				const func = el => {
					return el.matches(selector)
				}
				return func
			case 'function':
				return selector
			default:
				console.error(`The type (\${typeof selector}) of the provided argument is not valid`)
		}
	}

	// Get next and previous sibling, adapted from:
	// https://gomakethings.com/finding-the-next-and-previous-sibling-elements-that-match-a-selector-with-vanilla-js/
	var getNextSibling = function (elem, selector) {

		// Added to return undefined is called with undefined
		if (_.isNil(elem)) {return undefined}

		// Get the next sibling element
		var sibling = elem.nextElementSibling;
	
		// If there's no selector, return the first sibling
		if (!selector) return sibling;

		const checker = generateChecker(selector)
	
		// If the sibling matches our selector, use it
		// If not, jump to the next sibling and continue the loop
		while (sibling) {
			if (checker(sibling)) return sibling;
			sibling = sibling.nextElementSibling
		}
	
	};
	var getPreviousSibling = function (elem, selector) {

		// Added to return undefined is called with undefined
		if (_.isNil(elem)) {return undefined}
		
		// Get the next sibling element
		var sibling = elem.previousElementSibling;
	
		// If there's no selector, return the first sibling
		if (!selector) return sibling;

		const checker = generateChecker(selector)
	
		// If the sibling matches our selector, use it
		// If not, jump to the next sibling and continue the loop
		while (sibling) {
			if (checker(sibling)) return sibling;
			sibling = sibling.previousElementSibling;
		}
	
	};


	// Get the last toc entry descendant from the provided one
	function getLastDescendant(el) {
		const row = getRow(el)
		if (_.isNil(row)) {return}
		const children = row.directChildren
		if (_.isEmpty(children)) {
			return row
		} else {
			return getLastDescendant(_.last(children))
		}
	}

	// Find all the cell ids contained within the target toc rows and all its descendants
	function getBlockIds(el) {
		const row = getRow(el)
		if (_.isNil(row)) {return}
		function getIndex(row) {
			return editor_state.notebook.cell_order.indexOf(get_link_id(row))
		}
		const start = getIndex(row)

		const lastChild = getLastDescendant(row)
		const end = getIndex(getNextSibling(lastChild, '.toc-row'))

		return editor_state.notebook.cell_order.slice(start, end < 0 ? Infinity : end)
	}
		
	window.toc_utils = {
		getNextSibling,
		getPreviousSibling,
		getLastDescendant,
		getBlockIds,
	}

	// Functions to set and propagate hidden and collapsed states

	function propagate_parent(div, parent=null) {
		if (parent != null) {
			div.allParents = _.union(div.allParents, [parent])	
		}
		if (_.isEmpty(div.directChildren)) {return}
		for (const child of div.directChildren) {
			propagate_parent(child, parent ?? div)
		}
	}

	// Returns true if the current hidden/collapsed toc state is different from the one saved in the file within cell metadata
	function stateDiffersFile(state) {
		for (const [id, st] of _.entries(state)) {
			if (has_cell_attribute(id, 'toc-hidden') != st.hidden) { return true }
			if (has_cell_attribute(id, 'toc-collapsed') != st.collapsed) { return true }
		}
		return false
	}

	function set_state(div, state, value, init = false) {
		div.classList.toggle(state, value)
		if (!init) {
			window.toc_state[get_link_id(div)][state] = value
			toc.classList.toggle('file-state-differs', stateDiffersFile(window.toc_state))
		}
		if (_.isEmpty(div.directChildren)) {return}
		for (const child of div.directChildren) {
			propagate_state(child, state)
		}
	}
	function propagate_state(div, state) {
		let new_state = `parent-\${state}`
		div.classList.toggle(new_state, false)
		// Check the parents for the state
		for (const parent of div.allParents) {
			if (parent.classList.contains(state)) {
				div.classList.toggle(new_state, true)
				break
			}
		}
		if (_.isEmpty(div.directChildren)) {return}
		for (const child of div.directChildren) {
			propagate_state(child, state)
		}
	}
	</script>
	""")
);

# ╔═╡ 6e2397db-6f95-44ed-b874-bb0e6c853169
md"""
## floating-ui library
"""

# ╔═╡ 3c27af28-4fee-4b74-ad10-f57c11237dbb
_floating_ui = HTLScript(@htl("""
<script>
	const floating_ui = await import('https://esm.sh/@floating-ui/dom')
	// window.floating_ui = floating_ui
</script>
"""));

# ╔═╡ e9413fd1-d43c-4288-bcfa-850c30cc9513
md"""
## modify\_cell_attributes
"""

# ╔═╡ c1fa9fa5-b35e-43c5-bd32-ebca9cb01848
_modify_cell_attributes = HTLScript(@htl("""
<script>
	function has_cell_attribute(cell_id, attr) {
		const md = editor_state.notebook.cell_inputs[cell_id].metadata
		return _.includes(md["custom_attrs"], attr)
	}
	
	function add_cell_attributes(cell_id, attrs) {
		pluto_actions.update_notebook((notebook) => {
			let md = notebook.cell_inputs[cell_id].metadata
			md["custom_attrs"] = _.union(md["custom_attrs"], attrs)
		})
		let cell = document.getElementById(cell_id)
		for (let attr of attrs) {
			cell.toggleAttribute(attr, true)
		}
	}

	function remove_cell_attributes(cell_id, attrs) {
		pluto_actions.update_notebook((notebook) => {
			let md = notebook.cell_inputs[cell_id].metadata
			let after = _.difference(md["custom_attrs"], attrs)
			if (_.isEmpty(after)) {
				delete md["custom_attrs"]
			} else {
				md["custom_attrs"] = after
			}
		})
		let cell = document.getElementById(cell_id)
		for (let attr of attrs) {
			cell.toggleAttribute(attr, false)
		}
	}

	function toggle_cell_attribute(cell_id, attr, force='toggle') {
		pluto_actions.update_notebook((notebook) => {
			let md = notebook.cell_inputs[cell_id].metadata
			let f = force == 'toggle' ? _.xor : force ? _.union : _.difference
			let after = f(md["custom_attrs"], [attr])
			if (_.isEmpty(after)) {
				delete md["custom_attrs"]
			} else {
				md["custom_attrs"] = after
			}
		})
		let cell = document.getElementById(cell_id)
		force == 'toggle' ? cell.toggleAttribute(attr) : cell.toggleAttribute(attr, force)
	}
</script>
"""));

# ╔═╡ e9668acb-451d-4d16-b9cb-cf0ddcd6a681
md"""
## modify\_notebook\_attributes
"""

# ╔═╡ d65daa79-cb1d-4425-9693-b737d43e9981
_modify_notebook_attributes = HTLScript(@htl("""
<script>
		function add_notebook_attributes(attrs) {
		pluto_actions.update_notebook((notebook) => {
			let md = notebook.metadata
			md["custom_attrs"] = _.union(md["custom_attrs"], attrs)
		})
		let notebook = document.querySelector('pluto-notebook')
		for (let attr of attrs) {
			notebook.toggleAttribute(attr, true)
		}
	}

	function remove_notebook_attributes(attrs) {
		pluto_actions.update_notebook((notebook) => {
			let md = notebook.metadata
			let after = _.difference(md["custom_attrs"], attrs)
			if (_.isEmpty(after)) {
				delete md["custom_attrs"]
			} else {
				md["custom_attrs"] = after
			}
		})
		let notebook = document.querySelector('pluto-notebook')
		for (let attr of attrs) {
			notebook.toggleAttribute(attr, false)
		}
	}

	function toggle_notebook_attribute(attr, force='toggle') {
		pluto_actions.update_notebook((notebook) => {
			let md = notebook.metadata
			let f = force == 'toggle' ? _.xor : force ? _.union : _.difference
			let after = f(md["custom_attrs"], [attr])
			if (_.isEmpty(after)) {
				delete md["custom_attrs"]
			} else {
				md["custom_attrs"] = after
			}
		})
		let notebook = document.querySelector('pluto-notebook')
		force == 'toggle' ? notebook.toggleAttribute(attr) : notebook.toggleAttribute(attr, force)
	}

	if (force_hide_enabled) {
	 	toggle_notebook_attribute('hide-enabled',true)
	}
</script>
"""));

# ╔═╡ 123da4b2-710e-4962-b255-80fb33894b79
md"""
## hide\_cell\_blocks
"""

# ╔═╡ 904a2b12-6ffa-4cf3-95cf-002cf2673099
_hide_cell_blocks = HTLScript(@htl("""
<script>
	// For each from and to, we have to specify `pluto-cell[id]` in the part before the comm and just `[id]` in the part after the comma to ensure the specificity of the two comma-separated selectors is the same (the part after the comma has the addition of `~ pluto-cell`, so it has inherently +1 element specificity)
	function hide_from_to_string(from_id, to_id) {
		if (_.isEmpty(from_id) && _.isEmpty(to_id)) {return ''}
		
		const from_preselector = _.isEmpty(from_id) ? '' : `pluto-cell[id='\${from_id}'], pluto-notebook[hide-enabled] [id='\${from_id}'] ~ `
		const to_style = _.isEmpty(to_id) ? '' : `pluto-notebook[hide-enabled] pluto-cell[id='\${to_id}'], pluto-notebook[hide-enabled] [id='\${to_id}'] ~ pluto-cell {
		display: block;
	}
	 `
		const style_string = 	`pluto-notebook[hide-enabled] \${from_preselector}pluto-cell {
		display: none;
	}
	\${to_style}
 `
		return style_string
		//return html`<style>\${style_string}</style>`
	}

	function hide_from_to_list_string(vector) {
		let out = ``
		for (const lims of vector) {
			const from = lims[0]
			const to = lims[1]
			
			out = `\${out}\t\${hide_from_to_string(from,to)}`
		}
		out = `\${out}\tpluto-cell[always-show] {
  			display: block !important;
  		}
  `
		return out
	}
	function hide_from_to_list(vector) {
		const str = hide_from_to_list_string(vector)
		return html`<style>\${str}</style>`
	}
	function hide_list_style(vector) {
		let style = document.getElementById('hide-cells-style')
		if (style == null) {
  			style = document.head.appendChild(html`<style id='hide-cells-style'></style>`)
		}
		style.innerHTML = hide_from_to_list_string(vector)
	}
</script>
"""));

# ╔═╡ 60075509-fbdb-48c8-8e63-69f6fd5218b5
md"""
## mutation\_observer
"""

# ╔═╡ 702d5075-baad-4c11-a732-d062213e00e4
_mutation_observer = HTLScript(@htl("""
<script>
	function toggle_state(name) {
		return (e) => {
			e.preventDefault()
			e.stopPropagation()
			let div = e.target.closest('div')
			const new_val = !div.classList.contains(name)
			set_state(div, name, new_val)
		}
	}

	function update_hidden(e) {
		let new_hide = []
		if (hide_preamble) {
			new_hide.push(['', get_link_id(toc.querySelector('div.toc-row'))])
		}
		let tracking_hidden = null
		let divs = toc.querySelectorAll('div.toc-row')
		for (const div of divs) {
			if (tracking_hidden != null) {
				const hidden = div.classList.contains('hidden') || div.classList.contains('parent-hidden')
				if (!hidden) {
					new_hide.push([tracking_hidden, get_link_id(div)])	
					tracking_hidden = null
				}
			} else {
				const hidden = div.classList.contains('hidden')
				if (hidden) {
					tracking_hidden = get_link_id(div)
				}
			}
		}
		if (tracking_hidden != null) {
				new_hide.push([tracking_hidden, ""])	
		}
		hide_list_style(new_hide)
	}

	// Reposition the hide_container using the floating-ui library
	function repositionTooltip(e) {
		const { computePosition } = floating_ui
		const ref = e.target
		const tooltip = ref.querySelector('.toc-hide-container')
		if (_.isNil(tooltip)) {
			console.warn("Something went wrong, no tooltip found")
			return
		}
		computePosition(ref, tooltip, {
			placement: "left",
			strategy: "fixed",
		}).then(pos => {
			tooltip.style.top = pos.y + "px"
		})
	}
	
	function process_row(div, history, old_state, new_state) {

		// We add the separator
		div.insertAdjacentElement('beforebegin', html`<div class='toc-row-separator'></div>`)
		// If we are just processing the first element (so the last row) we also add a separator at the bottom
		if (_.isEmpty(new_state) && _.every(history, _.isEmpty)) {
			div.insertAdjacentElement('afterend', html`<div class='toc-row-separator'></div>`)
		}

		// We add the reposition event to the row
		div.addEventListener('mouseenter', repositionTooltip)
		
		let id = get_link_id(div)
		const a = div.querySelector('a')
		let old_f = a.onclick;
		a.onclick = (e) => {
			e.preventDefault()
			// We avoid triggering the click if coming out of a drag
			if (toc.classList.contains('recent-drag')) { return }
			old_f(e)
		}			
		const level = getHeadingLevel(div)
		if (level > 1) {
			history[level].unshift(div)
		}
		// We iterate through the history and assign the direct children if they exist, while clearing lower levels history
		for (let i = 6; i > level; i--) {
			if (_.isEmpty(history[i])) {continue}
			if (div.directChildren != undefined) {throw('multiple level with children, unexpected!')}
			div.directChildren = history[i]
			history[i] = [] // empty array
		}
		const collapse_span = a.insertAdjacentElement('afterbegin', html`<span class='toc-icon toc-collapse'>`)
		let hide_style = `--height: \${a.clientHeight}px`
		const hide_container = div.insertAdjacentElement('afterbegin', html`<span class='toc-hide-container' style='\${hide_style}'>`)
		const hide_span = hide_container.insertAdjacentElement('afterbegin', html`<span class='toc-icon toc-hide'>`)
		hide_span.addEventListener('click', (e) => {
			toggle_state('hidden')(e)
			update_hidden(e)
		})
		if (div.directChildren == undefined) {
			collapse_span.classList.toggle('no-children', true)
		} else {
			propagate_parent(div)
			collapse_span.addEventListener('click', toggle_state('collapsed'))
		}
		let md = editor_state.notebook.cell_inputs[id].metadata
		let collapsed = old_state[id]?.collapsed ??  _.includes(md['custom_attrs'], 'toc-collapsed')
		let hidden = old_state[id]?.hidden ?? _.includes(md['custom_attrs'], 'toc-hidden')
		set_state(div, 'collapsed', collapsed, true)
		set_state(div, 'hidden', hidden, true)
		new_state[id] = { collapsed, hidden }
		
	}

	const observer = new MutationObserver(() => {
		const rows = toc.querySelectorAll('section div.toc-row')
		let old_state = window.toc_state ?? {}
		let new_state = {}
		let history = {
			2: [],
			3: [],
			4: [],
			5: [],
			6: [],
		}
		for (const row of [...rows].reverse()) {
			process_row(row, history, old_state, new_state)
		}
		window.toc_state = new_state
		toc.classList.toggle('file-state-differs', stateDiffersFile(new_state))
		update_hidden()
	})

	observer.observe(toc, {childList: true})
</script>
"""),
"observer.disconnect()"
);

# ╔═╡ a271f2cd-b941-46af-888d-3274d21b3703
md"""
## move\_entries\_handler
"""

# ╔═╡ 5f60d643-d79c-4081-a31e-603e062e544f
_move_entries_handler = HTLScript(@htl("""
<script>
	const { default: interact } = await import('https://esm.sh/interactjs')

	// We have to enable dynamicDrop to have dropzone recomputed on dragmove
	interact.dynamicDrop(true)

	function dragEnabler(e) {
		if (!toc.classList.contains('drag_enabled') || e.key !== 'Shift') { return true }
		switch (e.type) {
			case "keydown":
				toc.classList.add('allow_all_drop')
				break;
			case "keyup":
				toc.classList.remove('allow_all_drop')
				break;
		}
		updateActiveSeparator()
	}

	const window_events = {
		keydown: dragEnabler,
		keyup: dragEnabler,
	}

	addScriptEventListeners(window, window_events)

	// Interact.js part

	let activeDrop = undefined

	function tagAdjacentSeparators(el, active) {
		const next = getNextSibling(el, '.toc-row-separator')
		const prev = getPreviousSibling(el, '.toc-row-separator')
		if (active) {
  			next?.classList.add('noshow')
  			prev?.classList.add('noshow')
		} else {
  			next?.classList.remove('noshow')
  			prev?.classList.remove('noshow')				
		}
	}

	function getSeparator(startElement, below, allowAll, headingLevel = 8) {
		let separator
		if (below) {
			const selector = '.toc-row:not(.parent-collapsed)'
			const checkerFunc = allowAll ? generateChecker(selector) : (el) => {
				if (!el.matches(selector)) { return false }
				// Check for the right heading level
				for (let i = headingLevel; i > 0; i--) {
					const cl = "H" + i
					if (el.classList.contains(cl)) { return true }
				}
				return false
			}
			const validRow = getNextSibling(startElement, checkerFunc)
			// If the activeDrop is the last row or the the last non-collapsed one, the validRow will be `undefined`, so in that case we take the last separator
			separator = getPreviousSibling(validRow, '.toc-row-separator') ?? _.last(toc.querySelectorAll('.toc-row-separator'))
		} else {
			separator = getPreviousSibling(startElement, '.toc-row-separator')
		}
		return separator
	}

	function getHigherParent(row, level) {
		const currentLevel = getHeadingLevel(row)
		if (currentLevel <= level) {return row}
		for (const par of row.allParents) {
			// Parents cycle from higher level to lower levels
			if (getHeadingLevel(par) <= level) {return par}
		}
		return row
	}
		
	let uncollapsed = []

	function reCollapse(row) {
		const parents = row?.allParents ?? []
		const toRemove = _.difference(uncollapsed, [...parents, row])
		for (const el of toRemove) {
			// debugger
			set_state(el, "collapsed", true)
			_.remove(uncollapsed, x => x === el)
		}
	}


	function updateDropZone(row) {
		const prev = toc.querySelector('.toc-row.active_drop')
		if (_.isNil(row) || prev === row) {return}
		if (prev?.timeoutId) {
			clearTimeout(prev.timeoutId)
			prev.timeoutId = undefined
		}
		prev?.classList.remove('active_drop')
		row.classList.add('active_drop')
		reCollapse(row)
		if (row.classList.contains('collapsed')) {
			row.timeoutId = setTimeout(() => {
				uncollapsed.push(row)
				set_state(row, "collapsed", false)
				updateActiveSeparator()
			}, 500)
		}
		activeDrop = row
	}

	function updateActiveSeparator() {
		const e = toc.lastDragEvent
		if (_.isNil(e)) { return }
		const elBelow = document.elementFromPoint(e.client.x, e.client.y)
		if (!elBelow.matches('.plutoui-toc :scope')) {
			// We are out of the ToC, recollapse and remove active separator
			reCollapse(undefined)
			toc.querySelector('.toc-row-separator.active')?.classList.remove('active')
			return
		}
		const rowBelow = getRow(elBelow)
		updateDropZone(rowBelow)
		if (_.isNil(activeDrop)) {return}
		const allowAll = toc.classList.contains('allow_all_drop')
		const headingLevel = getHeadingLevel(toc.draggedElement)
		const { y, height } = activeDrop.getBoundingClientRect()
		let thresholdY = y + height/2
		if (!allowAll) {
			// We only allow putting the dragged element above/below rows with equal or higher heading level
			const currentHeadingLevel = getHeadingLevel(activeDrop)
			if (currentHeadingLevel > headingLevel) {
				// We update the threshold based on the relevant parent
				const par = getHigherParent(activeDrop, headingLevel)
				const { y, height } = par.getBoundingClientRect()
				thresholdY = y + height/2						
			}
		}
		// Check if the current position of the mouse is below or above the middle of the active drop zone
		const isBelow = e.client.y > thresholdY
		const newSep = getSeparator(activeDrop, isBelow, allowAll, headingLevel)
		const currentSep = toc.querySelector('.toc-row-separator.active') ?? newSep
		if (currentSep !== newSep) {
			currentSep.classList.remove('active')
		}
		newSep.classList.add('active')
	}

	const dragHandles = interact('.toc-row').draggable({
		cursorChecker (action, interactable, element, interacting) {
			// console.log({action, interactable, element, interacting})
			return null
		},
		manualStart: true, // needed for consistent start after hold
		listeners: {
			start: function (e) {
				toc.classList.add('drag_enabled')
				const row = e.target
				// console.log('start: ', e)
				toc.lastDragEvent = e
				row.classList.add('dragged')
				toc.draggedElement = row
				tagAdjacentSeparators(row, true)
			},
			move: function (e) {
				toc.lastDragEvent = e
				updateActiveSeparator()
			},
			// move: function (e) {console.log('move: ',e)},
			end: function (e) {
				activeDrop = undefined
				e.preventDefault()
				toc.lastDragEvent = e
				// console.log('end: ', e)
				const row = e.target
				// Cleanup
				row.classList.remove('dragged')
				toc.classList.remove('drag_enabled')	
				for (const el of toc.querySelectorAll('.active_drop')) {
					el.classList.remove('active_drop')
				}
				reCollapse()				
				tagAdjacentSeparators(row, false)				
				toc.classList.remove('allow_all_drop')
				// We temporary set the recentDrag flag
				toc.classList.add('recent-drag')
				setTimeout(() => {
					toc.classList.remove('recent-drag')
				}, 300)
				// Check if there is an active dropzone
				const dropZone = toc.querySelector('.toc-row-separator.active')
				if (_.isNil(dropZone) || dropZone.classList.contains('noshow')) {return}
				dropZone.classList.remove('active')
				// We find the cell after the active separator and move the dragged row before that
				const rowAfter = getNextSibling(dropZone)
				const cellIdsToMove = getBlockIds(row)
				// Find the index of the cell that will stay after our moved block
				const end = editor_state.notebook.cell_order.indexOf(get_link_id(rowAfter))
				// If we got -1, it means we have to put the cells at the end
				pluto_actions.move_remote_cells(cellIdsToMove, end < 0 ? Infinity : end)
				toc.draggedElement = undefined		
			},
		}
	}).on('hold',function (e) {
		if (document.body.classList.contains('disable_ui')) { console.log('UI disabled, no interaction!'); return }
		e.preventDefault()
		e.stopImmediatePropagation()
		e.stopPropagation()
		// console.log('this is hold', e)
		var interaction = e.interaction

	    if (!interaction.interacting()) {
	      interaction.start(
	        { name: 'drag' },
	        e.interactable,
	        e.currentTarget,
	      )
	    }
	})

</script>
"""), """
dragHandles.unset()
""");

# ╔═╡ 6dbebad0-cc03-499c-9d3a-0aa7e9b32549
md"""
## header_manipulation
"""

# ╔═╡ ef5eff51-e6e4-4f40-8763-119cbd479d66
_header_manipulation = HTLScript(@htl("""
<script>
	const header = toc.querySelector('header')
	const header_container = header.insertAdjacentElement('afterbegin', html`<span class='toc-header-container'>`)
	
	
	const notebook_hide_icon = header_container.insertAdjacentElement('beforeend', html`<span class='toc-header-icon toc-header-hide'>`)
	
	const save_file_icon = header_container.insertAdjacentElement('beforeend', html`<span class='toc-header-icon toc-header-save'>`)
	save_file_icon.addEventListener('click', save_to_file)

	header_container.insertAdjacentElement('beforeend', html`<span class='toc-header-filler'>`)
	
	header.addEventListener('click', e => {
		if (e.target != header) {return}
		scroll_to(cell, {block: 'center', behavior: 'smooth'})
	})

	header.addEventListener('mouseenter', (e) => {
		floating_ui.computePosition(header, header_container, {
			placement: "left",
			strategy: "fixed",
		}).then(pos => {
			header_container.style.top = pos.y + "px"
			// header_container.style.left = pos.x + "px"
			// header_container.style.right = `calc(1rem + min(80vw, 300px))`
		})
	})

	notebook_hide_icon.addEventListener('click', (e) => {
			// We find the x coordinate of the pluto-notebook element, to avoid missing the cell when UI is disabled
			const { x } = document.querySelector('pluto-notebook').getBoundingClientRect()
			const ref = document.elementFromPoint(x+1,100).closest('pluto-cell')
			const { y } = ref.getBoundingClientRect()
			toggle_notebook_attribute('hide-enabled')
			const dy = ref.getBoundingClientRect().y - y
			window.scrollBy(0, dy)
	})
</script>
"""));

# ╔═╡ 7b8f25a8-e0cf-4b1b-8cfc-9de6334e75dd
md"""
## save\_to\_file
"""

# ╔═╡ 2ece4464-df5e-48e5-96d2-607213daebda
_save_to_file = HTLScript(@htl("""
<script>
	function save_to_file() {
		const state = window.toc_state
		for (const [k,v] of Object.entries(state)) {
			toggle_cell_attribute(k, 'toc-hidden', v.hidden)	
			toggle_cell_attribute(k, 'toc-collapsed', v.collapsed)	
		}
		setTimeout(() => {
			toc.classList.toggle('file-state-differs', stateDiffersFile(state))
		}, 500)
	}
</script>
"""));

# ╔═╡ c770fcab-93c0-4de5-b097-72c190ba0899
md"""
# Style
"""

# ╔═╡ 4426a0b3-98dc-49a0-8ecc-b57d0492736f
md"""
## header
"""

# ╔═╡ 5802c307-d68d-4e00-b6b2-d98ce295acae
_header_style = @htl """
<style>	
	.plutoui-toc header {
		cursor: pointer;
	}
	span.toc-header-container {
		position: fixed;
		display: none;
		--size: 25px;
		height: calc(51px - 1rem);
		flex-direction: row-reverse;
		right: calc(1rem + min(80vh, 300px));
	}
	.toc-header-icon {
		margin-right: 0.3rem;
		align-self: stretch;
		display: inline-block;
		width: var(--size);
		background-size: var(--size) var(--size);
	    background-repeat: no-repeat;
	    background-position: center;
		filter: var(--image-filters);
		cursor: pointer;
	}
	.toc-header-filler {
		margin: .25rem;
	}
	header:hover span.toc-header-container,
	span.toc-header-container:hover {
		display: flex;
	}
	.toc-header-hide {
		background-image: url(https://cdn.jsdelivr.net/gh/ionic-team/ionicons@5.5.1/src/svg/eye-outline.svg);
		opacity: 50%;
		--size: 1em;
	}
	.toc-header-save {
		background-image: url(https://cdn.jsdelivr.net/gh/ionic-team/ionicons@5.5.1/src/svg/save-outline.svg);
		opacity: 50%;
	}
	nav:not(.file-state-differs) .toc-header-save {
		display: none;
	}
	pluto-notebook[hide-enabled] span.toc-header-hide {
		background-image: url(https://cdn.jsdelivr.net/gh/ionic-team/ionicons@5.5.1/src/svg/eye-off-outline.svg);
	}
</style>
""";

# ╔═╡ 59e74c4f-c561-463e-b096-e9e587417285
md"""
## toc_row
"""

# ╔═╡ 0b11ce0a-bc66-41d2-9fbf-1be98b1ce39b
_toc_row_style = @htl """
<style>
	span.toc-hide-container {
		--width: min(80vw, 300px);
		position: fixed;
		display: flex;
		right: calc(var(--width) + 1rem + 22px - 100px);
		height: var(--height);
		width: 100px;
		z-index: -1;
	}
	span.toc-hide {
		visibility: hidden;
		opacity: 50%;
		background-image: url(https://cdn.jsdelivr.net/gh/ionic-team/ionicons@5.5.1/src/svg/eye-outline.svg);
		cursor: pointer;
	}
	div.toc-row.hidden span.toc-hide {
		background-image: url(https://cdn.jsdelivr.net/gh/ionic-team/ionicons@5.5.1/src/svg/eye-off-outline.svg);
	}
	span.toc-hide-container:hover > .toc-hide,
	div.toc-row:hover .toc-hide {
		visibility: visible;
	}
	div.toc-row a {
		display: flex;
	}
	span.toc-icon {
		--size: 17px;
		display: block;
		align-self: stretch;
		background-size: var(--size) var(--size);
	    background-repeat: no-repeat;
	    background-position: center;
		width: var(--size);
		filter: var(--image-filters);
	}
	span.toc-collapse {
		background-image: url(https://cdn.jsdelivr.net/gh/ionic-team/ionicons@5.5.1/src/svg/chevron-down.svg);
		margin-right: 3px;
		min-width: var(--size);
	}
	.plutoui-toc section div.toc-row.collapsed span.toc-collapse {
		background-image: url(https://cdn.jsdelivr.net/gh/ionic-team/ionicons@5.5.1/src/svg/chevron-forward.svg);
	}
	.plutoui-toc section div.toc-row a span.toc-collapse.no-children {
		background-image: none;
	}
	div.toc-row.parent-hidden {
		text-decoration: underline dotted .5px;
		text-underline-offset: 2px;
	}
	div.toc-row.hidden {
		text-decoration: underline dashed 1px;
		text-underline-offset: 2px;
	}
	.plutoui-toc div.parent-collapsed {
		display: none;
	}
	pluto-notebook[hide-enabled] div.toc-row.hidden,
	pluto-notebook[hide-enabled] div.toc-row.parent-hidden {
		display: none;
	}
	.drag_enabled .toc-row.dragged {
		border: 2px dashed grey;
	}
</style>
""";

# ╔═╡ 8f55cdc7-8409-4685-a154-52a82b91074c
md"""
## row-separator
"""

# ╔═╡ e3e3f46b-8879-4f7c-ad6a-12b4d27ac27a
_row_separator_style = @htl """
<style>
	div.toc-row-separator {
		height: 2px;
		margin: 3px 0px;
		background: #aaa;
		display: none;
	}
	div.toc-row-separator.active {
		display: block;
	}
	div.toc-row-separator.active.noshow {
		display: none;
	}
</style>
"""

# ╔═╡ 3244e8a5-b710-4a31-8a5d-ea529a7d47bd
md"""
## always show output
"""

# ╔═╡ 9b27f07a-7aaa-41f2-806c-56b7d9fc5f96
_always_show_output_style = @htl """
<style>
	/* This style permits to have a cell whose output is still being shown when
	   the cell is hidden. This is useful for having hidden cells that still are
	   sending HTML as output (like ToC and BondTable) */
	
	pluto-notebook[hide-enabled] pluto-cell[always-show-output] {
		display: block !important;
	}
	pluto-notebook[hide-enabled] pluto-cell[always-show-output]:not(.code_differs) > pluto-input,
	pluto-notebook[hide-enabled] pluto-cell[always-show-output]:not(.code_differs) > pluto-shoulder,
	pluto-notebook[hide-enabled] pluto-cell[always-show-output]:not(.code_differs) > pluto-trafficlight,
	pluto-notebook[hide-enabled] pluto-cell[always-show-output]:not(.code_differs) > pluto-runarea,
	pluto-notebook[hide-enabled] pluto-cell[always-show-output]:not(.code_differs) > button {
		display: none;
	}
	pluto-notebook[hide-enabled] pluto-cell[always-show-output]:not(.code_differs) {
		margin-top: 0px;
	}
</style>
"""

# ╔═╡ 0aac28b7-4771-447c-ab62-92250f46154f
md"""
# Main Function
"""

# ╔═╡ a1a09dae-b441-484e-8f40-e51e31fb34dd
"""
	ExtendedTableOfContents(;hide_preamble = true, force_hide_enabled = hide_preamble, kwargs...)

# Keyword Arguments
- `hide_preamble` -> When true, all the cells from the beginning of the notebook till the first heading are hidden (when the notebook is in `hide-enabled` state)
- `force_hide_enabled` -> Set the notebook `hide-enabled` status to true when creating the ToC. This status is used to decide whether to show or not hidden cells via CSS.
- `kwargs` -> The remaining kwargs are simply passed to `TableOfContents` from PlutoUI which is used internally to generate the ToC.

# Description

Extends the `TableOfContents` from `PlutoUI` and adds the following functionality:

## Hiding Heading/Cells
Hiding headings and all connected cells from notebook view can be done via ExtendedTableOfContents
- All cells before the first heading are automatically hidden from the notebook
- All hidden cells/headings can be shown by pressing the _eye_ button that appears while hovering on the ToC title. 
  - When the hidden cells are being shown, the hidden headings in the ToC are underlined
- Hidden status of specific headings in the notebook can be toggled by pressing on the eye button that appears to the left each heading when hovering over them

## Collapsing Headings in ToC
ToC headings are grouped based on heading level, sub-headings at various levels can be collapsed by using the caret symbol that appears to the left of headings in the ToC upon hover.

## Save Hide/Collapsed status on notebook file
Preserving the status of collapsed/hidden heading is supported by writing to the notebook file using notebook and cell metadata, allowing to maintain the status even upon reload of Julia/Pluto
- When the current collapsed/hidden status of each heading is not reflected in the notebook file, a save icon/button appears on the left of the ToC title upon hover. Clicking the icon saves the current state in the notebook file.

## Changing Headings/Cells order
The `ExtendedTableOfContents` allow to re-order the cell groups identified by each heading within the notebook:
- Each cell group is identified by the cell containing the heading, plus all the cells below it and up to the next heading (excluded)
- Holding the mouse on a ToC heading triggers the ability to move headings around
  - The target heading is surrounded by a dashed border
  - While moving the mouse within the ToC, a visual separator appears to indicate the position where the dragged heading will be moved to, depending on the mouse position
  - Hovering on collapsed headings for at least 300ms opens them up to allow moving headings within collapsed parents
- By default, headings can only be moved below or above headings of equal or lower level (H1 < H2 < H3...)
  - Holding shift during the dragging process allows to put headings before/after any other heading regardless of the level


# Example usage

# State Manipulation

![State_Manipulation](https://user-images.githubusercontent.com/12846528/217245898-5166682d-b41d-4f1e-b71b-4d7f69c8f192.gif)

# Cell Reordering

![Cell_Reordering](https://user-images.githubusercontent.com/12846528/217245256-58e4d537-9547-42ec-b1d8-2994b6bcaf51.gif)
"""
ExtendedTableOfContents(;hide_preamble = true, force_hide_enabled = hide_preamble,kwargs...) = @htl """
$(TableOfContents(;kwargs...))
$(combine_scripts([
	"const hide_preamble = $hide_preamble",
	"const force_hide_enabled = $force_hide_enabled",
	_smooth_scroll,
	_basics,
	_floating_ui,
	_modify_notebook_attributes,
	_modify_cell_attributes,
	_hide_cell_blocks,
	_save_to_file,
	_header_manipulation,
	"cell.toggleAttribute('always-show', true)",
	_mutation_observer,
	_move_entries_handler,
]))
$_header_style
$_toc_row_style
$_row_separator_style
$_always_show_output_style
"""

# ╔═╡ d05d4e8c-bf50-4343-b6b5-9b77caa646cd
ExtendedTableOfContents()

# ╔═╡ 111d359f-0a35-43f0-b30e-a52b8c69faa2
md"""
# Exports
"""

# ╔═╡ 10623400-35be-49fe-9fc2-3c31d6f66610
md"""
# Helper Functions
"""

# ╔═╡ c681160d-b4e0-496a-8561-78fa25bf2483
md"""
## show output when hidden
"""

# ╔═╡ 95b8bf53-770a-4a11-8664-eb0e0dcfb299
begin
"""
	show_output_when_hidden(x)
Wraps the given input `x` inside a custom HTML code created with
`HypertextLiteral.@htl` that adds the `always-show-output` attribute to the
calling Pluto cell.

This makes sure that the cell output remains visible in the HTML even when the
cell is hidden using the [`ExtendedTableOfContents`](@ref) cell hiding feature.
This is mostly useful to allow having cells that generate output to be rendered
within the notebook as hidden cells.

The provided attribute will make sure (via CSS) that cell will look exactly like
a hidden cell except for its output element. When the output is floating (like
for [`BondTable`](@ref) or [`ExtendedTableOfContents`](@ref)), this will make
the cell hidden while the rendered output visible.

# Example usage
```julia
BondTable([bonds...]) |> show_output_when_hidden
```

The code above will allow putting the cell defining the `BondTable` within a
hidden part of the notebook while still rendering the floating BondTable.
Without this function, the `BondTable` generating cell would need to be located
inside a non-hidden part of the notebook.

# Note
When calling this function with an input object that is not of type `HTML` or
`HypertextLiteral.Result`, the function will wrap the object first using `@htl`
and `PlutoRunner.embed_display`. Since the `embed_display` function is only
available inside of Pluto,  
"""
show_output_when_hidden(x::Union{HTML, HypertextLiteral.Result}) = @htl("""
$x
<script>
	const cell = currentScript.closest('pluto-cell')
	cell.toggleAttribute('always-show-output', true)

	invalidation.then(() => {
		cell.toggleAttribute('always-show-output', false)
	})
</script>
""")
show_output_when_hidden(x) = isdefined(Main, :PlutoRunner) ?
show_output_when_hidden(@htl("$(embed_display(x))")) : error("You can't call
this function outside Pluto")
end

# ╔═╡ 1bdb12d3-899d-4ce0-a053-6cf1fa15072d
export ExtendedTableOfContents, show_output_when_hidden

# ╔═╡ 48540378-5b63-4c20-986b-75c08ceb24b7
md"""
# Tests
"""

# ╔═╡ 7dce5ffb-48ad-4ef4-9e13-f7a34794170a
md"""
The weird looking 3 below is inside a hidden cell that has been tagged with `show_output_when_hidden`
"""

# ╔═╡ 4373ab10-d4e7-4e25-b7a8-da1fcf3dcb0c
# ╠═╡ custom_attrs = ["toc-hidden"]
md"""
## Hidden Heading
"""

# ╔═╡ f6e74270-bd75-4367-a0b2-1e10e1336b6c
# ╠═╡ skip_as_script = true
#=╠═╡
3 |> show_output_when_hidden
  ╠═╡ =#

# ╔═╡ 091dbcb6-c5f6-469b-889a-e4b23197d2ad
md"""
## very very very very very very very very very long
"""

# ╔═╡ c9bcf4b9-6769-4d5a-bbc0-a14675e11523
md"""
### Short
"""

# ╔═╡ 6ddee4cb-7d76-483e-aed5-bde46280cc5b
md"""
## Random JS Tests
"""

# ╔═╡ 239b3956-69d7-43dc-80b8-92f43b84aada
@htl """
<div class='parent'>
	<span class='child first'></span>
	<span class='child second'></span>
	<span class='child third'></span>
</div>
<style>
	div.parent {
		position: fixed;
		top: 30px;
		left: 30px;
		background: lightblue;
		display: flex;
		height: 30px;
	}
	span.child {
		align-self: stretch;
		width: 20px;
		display: inline-block;
		background: green;
		margin: 5px 0px;
	}
</style>
""";

# ╔═╡ c4490c71-5994-4849-914b-ec1a88ec7881
# ╠═╡ custom_attrs = ["toc-collapsed"]
md"""
# Fillers
"""

# ╔═╡ fd6772f5-085a-4ffa-bf55-dfeb8e93d32b
md"""
## More Fillers
"""

# ╔═╡ 863e6721-98f1-4311-8b9e-fa921030f7d7
md"""
## More Fillers
"""

# ╔═╡ 515b7fc0-1c03-4c82-819b-4bf70baf8f14
md"""
## More Fillers
"""

# ╔═╡ e4a29e2e-c2ec-463b-afb2-1681c849780b
md"""
## More Fillers
"""

# ╔═╡ eb559060-5da1-4a9e-af51-9007392885eb
md"""
## More Fillers
"""

# ╔═╡ 1aabb7b3-692f-4a27-bb34-672f8fdb0753
md"""
## More Fillers
"""

# ╔═╡ ac541f37-7af5-49c8-99f8-c5d6df1a6881
md"""
## More Fillers
"""

# ╔═╡ fdf482d1-f8fa-4628-9417-2816de367e94
md"""
## More Fillers
"""

# ╔═╡ 6de511d2-ad79-4f0e-95ff-ce7531f3f0c8
md"""
## More Fillers
"""

# ╔═╡ a8bcd2cc-ae01-4db7-822f-217c1f6bbc8f
md"""
## More Fillers
"""

# ╔═╡ 9ddc7a20-c1c9-4af3-98cc-3b803ca181b5
md"""
## More Fillers
"""

# ╔═╡ 6dd2c458-e02c-4850-a933-fe9fb9dcdf39
md"""
## More Fillers
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
HypertextLiteral = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
PlutoDevMacros = "a0499f29-c39b-4c5c-807c-88074221b949"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
HypertextLiteral = "~0.9.4"
PlutoDevMacros = "~0.5.0"
PlutoUI = "~0.7.49"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.9.2"
manifest_format = "2.0"
project_hash = "ff6960561c5ccdacc631ec88bb1ce8c97f73df95"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"
version = "1.1.1"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"
version = "1.0.5+0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Downloads]]
deps = ["ArgTools", "FileWatching", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"
version = "1.6.0"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"
version = "0.6.3"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"
version = "7.84.0+0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"
version = "1.10.2+0"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "OpenBLAS_jll", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"
version = "2.28.2+0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"
version = "2022.10.11"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"
version = "1.2.0"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"
version = "0.3.21+4"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "151d91d63d8d6c1a5789ecb7de51547e00480f1b"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.4"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "FileWatching", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
version = "1.9.2"

[[deps.PlutoDevMacros]]
deps = ["HypertextLiteral", "InteractiveUtils", "MacroTools", "Markdown", "Pkg", "Random", "TOML"]
git-tree-sha1 = "b3fc642d889e685ee0a064a26c19f56266999e46"
uuid = "a0499f29-c39b-4c5c-807c-88074221b949"
version = "0.5.6"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "b478a748be27bd2f2c73a7690da219d0844db305"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.51"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"
version = "0.7.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SparseArrays]]
deps = ["Libdl", "LinearAlgebra", "Random", "Serialization", "SuiteSparse_jll"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
version = "1.9.0"

[[deps.SuiteSparse_jll]]
deps = ["Artifacts", "Libdl", "Pkg", "libblastrampoline_jll"]
uuid = "bea87d4a-7f5b-5778-9afe-8cc45184846c"
version = "5.10.1+6"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"
version = "1.0.3"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"
version = "1.10.0"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[deps.URIs]]
git-tree-sha1 = "ac00576f90d8a259f2c9d823e91d1de3fd44d348"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"
version = "1.2.13+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"
version = "5.8.0+0"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"
version = "1.48.0+0"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
version = "17.4.0+0"
"""

# ╔═╡ Cell order:
# ╠═464fc674-5ed7-11ed-0aff-939456ebc5a8
# ╠═d05d4e8c-bf50-4343-b6b5-9b77caa646cd
# ╟─46520c1a-bbd8-46aa-95d9-bad3d220ee85
# ╟─6fb280c9-996e-4e0b-beb4-72e4acc9dada
# ╟─98191362-88d4-42f7-a3dc-d497b012b42c
# ╠═3ea073ee-59d5-43a2-98c8-a309ce327418
# ╟─aa74f780-96c5-4b91-9658-a34c8c3fcab9
# ╠═a777b426-42e9-4c91-aebd-506388449042
# ╠═6e2397db-6f95-44ed-b874-bb0e6c853169
# ╠═3c27af28-4fee-4b74-ad10-f57c11237dbb
# ╟─e9413fd1-d43c-4288-bcfa-850c30cc9513
# ╠═c1fa9fa5-b35e-43c5-bd32-ebca9cb01848
# ╟─e9668acb-451d-4d16-b9cb-cf0ddcd6a681
# ╠═d65daa79-cb1d-4425-9693-b737d43e9981
# ╠═123da4b2-710e-4962-b255-80fb33894b79
# ╠═904a2b12-6ffa-4cf3-95cf-002cf2673099
# ╠═60075509-fbdb-48c8-8e63-69f6fd5218b5
# ╠═702d5075-baad-4c11-a732-d062213e00e4
# ╟─a271f2cd-b941-46af-888d-3274d21b3703
# ╠═5f60d643-d79c-4081-a31e-603e062e544f
# ╟─6dbebad0-cc03-499c-9d3a-0aa7e9b32549
# ╠═ef5eff51-e6e4-4f40-8763-119cbd479d66
# ╠═7b8f25a8-e0cf-4b1b-8cfc-9de6334e75dd
# ╠═2ece4464-df5e-48e5-96d2-607213daebda
# ╟─c770fcab-93c0-4de5-b097-72c190ba0899
# ╟─4426a0b3-98dc-49a0-8ecc-b57d0492736f
# ╠═5802c307-d68d-4e00-b6b2-d98ce295acae
# ╠═59e74c4f-c561-463e-b096-e9e587417285
# ╠═0b11ce0a-bc66-41d2-9fbf-1be98b1ce39b
# ╟─8f55cdc7-8409-4685-a154-52a82b91074c
# ╠═e3e3f46b-8879-4f7c-ad6a-12b4d27ac27a
# ╟─3244e8a5-b710-4a31-8a5d-ea529a7d47bd
# ╠═9b27f07a-7aaa-41f2-806c-56b7d9fc5f96
# ╟─0aac28b7-4771-447c-ab62-92250f46154f
# ╠═a1a09dae-b441-484e-8f40-e51e31fb34dd
# ╟─111d359f-0a35-43f0-b30e-a52b8c69faa2
# ╠═1bdb12d3-899d-4ce0-a053-6cf1fa15072d
# ╟─10623400-35be-49fe-9fc2-3c31d6f66610
# ╟─c681160d-b4e0-496a-8561-78fa25bf2483
# ╠═95b8bf53-770a-4a11-8664-eb0e0dcfb299
# ╟─48540378-5b63-4c20-986b-75c08ceb24b7
# ╟─7dce5ffb-48ad-4ef4-9e13-f7a34794170a
# ╟─4373ab10-d4e7-4e25-b7a8-da1fcf3dcb0c
# ╠═f6e74270-bd75-4367-a0b2-1e10e1336b6c
# ╠═091dbcb6-c5f6-469b-889a-e4b23197d2ad
# ╠═c9bcf4b9-6769-4d5a-bbc0-a14675e11523
# ╟─6ddee4cb-7d76-483e-aed5-bde46280cc5b
# ╠═239b3956-69d7-43dc-80b8-92f43b84aada
# ╠═c4490c71-5994-4849-914b-ec1a88ec7881
# ╠═fd6772f5-085a-4ffa-bf55-dfeb8e93d32b
# ╠═863e6721-98f1-4311-8b9e-fa921030f7d7
# ╠═515b7fc0-1c03-4c82-819b-4bf70baf8f14
# ╠═e4a29e2e-c2ec-463b-afb2-1681c849780b
# ╠═eb559060-5da1-4a9e-af51-9007392885eb
# ╠═1aabb7b3-692f-4a27-bb34-672f8fdb0753
# ╠═ac541f37-7af5-49c8-99f8-c5d6df1a6881
# ╠═fdf482d1-f8fa-4628-9417-2816de367e94
# ╠═6de511d2-ad79-4f0e-95ff-ce7531f3f0c8
# ╠═a8bcd2cc-ae01-4db7-822f-217c1f6bbc8f
# ╠═9ddc7a20-c1c9-4af3-98cc-3b803ca181b5
# ╠═6dd2c458-e02c-4850-a933-fe9fb9dcdf39
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
