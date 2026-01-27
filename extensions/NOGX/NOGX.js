if (typeof __NOGX_ready === 'undefined') __NOGX_ready = false;
__NOGX_canvasSizeW = 640;
__NOGX_canvasSizeH = 360;
__NOGX_limitAspectRatio = false;
__NOGX_minAspectRatio = 16/9;
__NOGX_maxAspectRatio = 16/9;

function __NOGX_init(limitAspectRatio, minAsp, maxAsp) {
	__NOGX_limitAspectRatio = limitAspectRatio;
	__NOGX_minAspectRatio = minAsp;
	__NOGX_maxAspectRatio = maxAsp;
	__NOGX_ready = true;
	__NOGX_update_canvas_size();
}
 
function __NOGX_update_canvas_size() {
	const canvasElement = Module.canvas;
	const dpr = window.devicePixelRatio || 1;
	const w = Math.max(document.documentElement.clientWidth || 0, window.innerWidth || 0) * dpr;
	const h = Math.max(document.documentElement.clientHeight || 0, window.innerHeight || 0) * dpr;
	const wFloor = Math.floor(w);
	const hFloor = Math.floor(h);
	
	let screenW = wFloor;
	let screenH = hFloor;
	
	if(__NOGX_limitAspectRatio) {
		const asp = wFloor/hFloor;
		var aspLimited = Math.min(Math.max(asp, __NOGX_minAspectRatio), __NOGX_maxAspectRatio);
		if(asp/aspLimited>=1) {
			screenW = Math.floor(screenH * aspLimited);
		} else {
			screenH = Math.floor(screenW / aspLimited);
		}
	}
	
	// blur fix:
	const screenWFix = screenW % 2 !== 0 ? screenW - 1 : screenW;
	const screenHFix = screenH % 2 !== 0 ? screenH - 1 : screenH;
	
	__NOGX_canvasSizeW = screenWFix;
	__NOGX_canvasSizeH = screenHFix;
	
	canvasElement.style.width = (screenWFix/dpr) + "px";
	canvasElement.style.height = (screenHFix/dpr) + "px";
}

function __NOGX_get_canvas_width() {
	return __NOGX_canvasSizeW;
}

function __NOGX_get_canvas_height() {
	return __NOGX_canvasSizeH;
}

