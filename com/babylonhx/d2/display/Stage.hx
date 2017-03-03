package com.babylonhx.d2.display;

import com.babylonhx.d2.events.KeyboardEvent;
import com.babylonhx.d2.events.TouchEvent;
import com.babylonhx.d2.events.Event;
import com.babylonhx.d2.events.EventDispatcher;
import com.babylonhx.d2.events.MouseEvent;
import com.babylonhx.d2.geom.Point;

import com.babylonhx.utils.GL;
import com.babylonhx.utils.GL.GLBuffer;
import com.babylonhx.utils.GL.GLFramebuffer;
import com.babylonhx.utils.GL.GLProgram;
import com.babylonhx.utils.GL.GLShader;
import com.babylonhx.utils.GL.GLTexture;
import com.babylonhx.utils.GL.GLUniformLocation;
import com.babylonhx.utils.typedarray.Float32Array;
import com.babylonhx.utils.typedarray.UInt16Array;
import com.babylonhx.utils.Image;

import com.babylonhx.cameras.FreeCamera;
import com.babylonhx.math.Vector3;
import com.babylonhx.materials.StandardMaterial;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.mesh.Mesh;

/**
 * ...
 * @author Krtolica Vujadin
 */
class Stage extends DisplayObjectContainer {
	
	var fs = [
		"precision highp float;",
		"varying vec2 d2_texCoord;",
		
		"uniform sampler2D uSampler;",
		"uniform vec4 color;",
		"uniform bool useTex;",
		
		"uniform mat4 cMat;",
		"uniform vec4 cVec;",
		
		"void main(void) {",
			"vec4 c;",
			"if (useTex) { c = texture2D(uSampler, d2_texCoord);  c.xyz *= c.w; }",
			"else c = color;",
			"c = (cMat * c) + cVec;",
			"c.xyz *= min(c.w, 1.0);",
			"gl_FragColor = c;",
		"}"
	].join("\n");
	
	var vs = [
		"precision highp float;",
		"attribute vec3 verPos;",
		"attribute vec2 texPos;",
		
		"uniform mat4 tMat;",
		
		"varying vec2 d2_texCoord;",
		
		"void main(void) {",
		"	d2_texCoord = texPos;",
		"	gl_Position = tMat * vec4(verPos, 1.0);",
		"}"
	].join("\n");
	
	public var _mouseX:Int = 0;
	public var _mouseY:Int = 0;
	
	private var _curBF:GLBuffer = null;
	private var _curEBF:GLBuffer = null;
	
	private var _curVC:GLBuffer = null;
	private var _curTC:GLBuffer = null;
	private var _curUT:Int = 0;
	private var _curTEX:GLTexture = null;
	
	private var _curBMD:BlendMode = BlendMode.NORMAL;

	public var stageWidth:Int;
	public var stageHeight:Int;
	
	private var _dpr:Float;
	
	private var _svec4_0:Float32Array;
	private var _svec4_1:Float32Array;
	
	private var _pmat:Float32Array;
	private var _umat:Float32Array;
	private var _smat:Float32Array;
	
	private var _knM:Bool;
	public var _mstack:MStack;
	public var _cmstack:CMStack;
	public var _sprg:WebGLProgram;
	
	public var _unitIBuffer:GLBuffer;
	
	private var _mcEvs:Array<MouseEvent>;
	private var _mdEvs:Array<MouseEvent>;
	private var _muEvs:Array<MouseEvent>;
	
	private var _smd:Array<Bool>;
	private var _smu:Array<Bool>;
	
	private var _smm:Bool;
	private var _srs:Bool;
	
	public var focus:DisplayObject;
	public var _focii:Array<DisplayObject>;
	public var _mousefocus:DisplayObject;
	
	private var _touches:Map<String, Dynamic> = new Map();
	
	private var _engine:Engine;
	public var engine(get, never):Engine;
	inline private function get_engine():Engine {
		return _engine;
	}

    #if (js || purejs || lime)
    public var Gl:GLRenderingContext;
    #else
    public var Gl = com.babylonhx.utils.GL;
    #end
	
	public function new(scene:Scene, dpr:Float = 1) {
		super();
		
		_engine = scene.getEngine();
        #if (js || purejs || lime)
        Gl = @:privateAccess _engine.Gl;
        #end

		engine.onResize.push(function() {
			this.stageWidth = engine.width;
			this.stageHeight = engine.height;
			this._resize();
		});
		engine.onAfterRender.push(this._drawScene);
		
		this._dpr = dpr;
		
		this.stage = this;
		
		this.stageWidth = engine.width;
		this.stageHeight = engine.height;
		
		this.focus				= null;			// keyboard focus, never Stage
		this._focii 			= [null, null, null];
		this._mousefocus 		= null;			// mouse focus of last mouse move, used to detect MOUSE_OVER / OUT, never Stage
		
		this._knM = false;					// know mouse
		this._mstack = new MStack();		// transform matrix stack
		this._cmstack = new CMStack();		// color matrix stack
		this._sprg = null;
		
		this._svec4_0	= Point._v4_Create();
		this._svec4_1	= Point._v4_Create();
		
		this._pmat = Point._m4_Create(new Float32Array([
			 1, 0, 0, 0,
			 0, 1, 0, 0,
			 0, 0, 1, 1,
			 0, 0, 0, 1
		]));	// project matrix
		
		this._umat = Point._m4_Create(new Float32Array([
			 2, 0, 0, 0,
			 0,-2, 0, 0,
			 0, 0, 2, 0,
			-1, 1, 0, 1
		]));	// unit matrix
		
		this._smat = Point._m4_Create(new Float32Array([
			 0, 0, 0, 0,
			 0, 0, 0, 0,
			 0, 0, 0.001, 0,
			 0, 0, 0, 1
		]));	// scale matrix
		
		this._mcEvs = [	new MouseEvent(MouseEvent.CLICK			,true), 
						new MouseEvent(MouseEvent.MIDDLE_CLICK	,true), 
						new MouseEvent(MouseEvent.RIGHT_CLICK	,true) ];
						
		this._mdEvs = [ new MouseEvent(MouseEvent.MOUSE_DOWN		,true),
						new MouseEvent(MouseEvent.MIDDLE_MOUSE_DOWN	,true),
						new MouseEvent(MouseEvent.RIGHT_MOUSE_DOWN	,true) ];
						
		this._muEvs = [ new MouseEvent(MouseEvent.MOUSE_UP			,true),
						new MouseEvent(MouseEvent.MIDDLE_MOUSE_UP	,true),
						new MouseEvent(MouseEvent.RIGHT_MOUSE_UP	,true) ];
		
		this._smd   = [false, false, false];	// stage mouse down, for each mouse button
		this._smu   = [false, false, false];	// stage mouse up, for each mouse button
		
		this._smm  = false;	// stage mouse move
		this._srs  = false;	// stage resized

        this._initShaders();
        this._initBuffers();
		
		this._resize();
		this._srs = true;
		
		var dummyMesh = Mesh.CreatePlane("dummymesh", 0.000001, scene);
		var dummyMaterial = new StandardMaterial("dummymaterial", scene);
		dummyMaterial.diffuseTexture = Texture.CreateFromImage(Image.createNoise(), "_dummy", scene);
        dummyMaterial.backFaceCulling = false;
		dummyMesh.material = dummyMaterial;
		
		var s:Sprite = new Sprite();
		s.graphics.beginFill();
		s.graphics.drawRect(-0.1, -0.1, 0.1, 0.1);
		s.graphics.endFill();
		s.x = -5000;
		addChild(s);
	}
	
	inline public function _getOrigin(org:Float32Array) {
		org[0] = this.stageWidth / 2;  
		org[1] = this.stageHeight / 2;  
		org[2] = -500;  
		org[3] = 1;
	}

    inline public function _updateCMStack() {
        _cmstack.update(this);
    }
	
	inline public function _setBF(bf:GLBuffer) {
		if (_curBF != bf) {
			Gl.bindBuffer(GL.ARRAY_BUFFER, bf);
			_curBF = bf;
		}
	}
	
	inline public function _setEBF(ebf:GLBuffer) {
		if(_curEBF != ebf) {
			Gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebf);
			_curEBF = ebf;
		}
	}
	
	inline public function _setVC(vc:GLBuffer) {
		if (_curVC != vc) {
			Gl.bindBuffer(GL.ARRAY_BUFFER, vc);
			Gl.vertexAttribPointer(_sprg.vpa, 3, GL.FLOAT, false, 0, 0);
			_curVC = _curBF = vc;
		}
	}
	
	inline public function _setTC(tc:GLBuffer) {
		if (_curTC != tc) {
			Gl.bindBuffer(GL.ARRAY_BUFFER, tc);
			Gl.vertexAttribPointer(_sprg.tca, 2, GL.FLOAT, false, 0, 0);
			_curTC = _curBF = tc;
		}
	}
	
	inline public function _setUT(ut:Int) {
		if (_curUT != ut) {
			Gl.uniform1i(_sprg.useTex, ut);
			_curUT = ut;
		}
	}
	
	inline public function _setTEX(tex:GLTexture) {
		if (_curTEX != tex) {
			engine._bindTexture(0, tex);
			_curTEX == tex;
		}
	}
	
	public function _setBMD(bmd:BlendMode) {
		//if(_curBMD != bmd) {
			if (bmd == BlendMode.NORMAL) {
				Gl.blendEquation(GL.FUNC_ADD);
				Gl.blendFunc(GL.ONE, GL.ONE_MINUS_SRC_ALPHA);
			}
			else if	(bmd == BlendMode.MULTIPLY) {
				Gl.blendEquation(GL.FUNC_ADD);
                Gl.blendFunc(GL.DST_COLOR, GL.ONE_MINUS_SRC_ALPHA);
			}
			else if	(bmd == BlendMode.ADD)	  {
                Gl.blendEquation(GL.FUNC_ADD);
                Gl.blendFunc(GL.ONE, GL.ONE);
			}
			else if (bmd == BlendMode.SUBTRACT) {
                Gl.blendEquationSeparate(GL.FUNC_REVERSE_SUBTRACT, GL.FUNC_ADD);
                Gl.blendFunc(GL.ONE, GL.ONE);
			}
			else if (bmd == BlendMode.SCREEN) {
                Gl.blendEquation(GL.FUNC_ADD);
                Gl.blendFunc(GL.ONE, GL.ONE_MINUS_SRC_COLOR);
			}
			else if (bmd == BlendMode.ERASE) {
                Gl.blendEquation(GL.FUNC_ADD);
                Gl.blendFunc(GL.ZERO, GL.ONE_MINUS_SRC_ALPHA);
			}
			else if (bmd == BlendMode.ALPHA) {
                Gl.blendEquation(GL.FUNC_ADD);
                Gl.blendFunc(GL.ZERO, GL.SRC_ALPHA);
			}
			
			_curBMD = bmd;
		//}
	}
	
	private function _getMakeTouch(id:Int) {  
		var t = this._touches["t" + id];
		if (t == null) {  
			t = { touch: null, target: null, act: 0 };  
			this._touches["t" + id] = t;
		}
		
		return t;
	}
	
	// touch events
	
	public function _onTD(x:Int, y:Int, pointerID:Int) {
		this._setStageMouse(x, y); 
		this._smd[0] = true; 
		this._knM = true;
		this._processMouseTouch();
	}
	public function _onTM(x:Int, y:Int, pointerID:Int) { 
		this._setStageMouse(x, y); 
		this._smm = true; 
		this._knM = true;
		this._processMouseTouch();
	}
	public function _onTU(x:Int, y:Int, pointerID:Int) { 
		this._smu[0] = true; 
		this._knM = true;
		this._processMouseTouch();
	}
	
	// mouse events
	
	public function _onMD(x:Int, y:Int, button:Int) { 
		this._setStageMouse(x, y); 
		this._smd[button] = true; 
		this._knM = true;  
		this._processMouseTouch(); 
	}
	
	public function _onMM(x:Int, y:Int) { 
		this._setStageMouse(x, y); 
		this._smm = true; 
		this._knM = true;  
		this._processMouseTouch(); 
	}
	
	public function _onMU(x:Int, y:Int, button:Int) { 
		this._smu[button] = true; 
		this._knM = true;  
		this._processMouseTouch();
	}
	
	// keyboard events
	
	public function _onKD(altKey:Bool, ctrlKey:Bool, shiftKey:Bool, keyCode:Int, charCode:Int) { 
		var ev = new KeyboardEvent(KeyboardEvent.KEY_DOWN, true);
		ev._setFromDom(altKey, ctrlKey, shiftKey, keyCode, charCode);
		if (this.focus != null && this.focus.stage != null) {
			this.focus.dispatchEvent(ev); 
		}
		else {
			this.dispatchEvent(ev);
		}
	}
	
	public function _onKU(altKey:Bool, ctrlKey:Bool, shiftKey:Bool, keyCode:Int, charCode:Int) { 
		var ev = new KeyboardEvent(KeyboardEvent.KEY_UP, true);
		ev._setFromDom(altKey, ctrlKey, shiftKey, keyCode, charCode);
		if (this.focus != null && this.focus.stage != null) {
			this.focus.dispatchEvent(ev); 
		}
		else {
			this.dispatchEvent(ev);
		}
	}
	
	public function _onRS(_) { 
		this._srs = true;
	}	
	
	public function _getDPR():Float {
		return _dpr;
	}
	
	inline public function _resize() {		
		this._setFramebuffer(null, this.stageWidth, this.stageHeight, false);
		this.dispatchEvent(new Event(Event.RESIZE));
	}

    private function _getShader(str:String, fs:Bool) {
        var shader:GLShader = null;
        if (fs)	{
			shader = Gl.createShader(GL.FRAGMENT_SHADER);
		}
        else {
			shader = Gl.createShader(GL.VERTEX_SHADER);
		}

        Gl.shaderSource(shader, str);
        Gl.compileShader(shader);
		
        if (Gl.getShaderParameter(shader, GL.COMPILE_STATUS) == 0) {
            trace(Gl.getShaderInfoLog(shader));
            return null;
        }
		
        return shader;
    }

    private function _initShaders() {			
		var fShader = this._getShader(fs, true );
        var vShader = this._getShader(vs, false);
		
		this._sprg = new WebGLProgram();
        this._sprg.prog = Gl.createProgram();
        Gl.attachShader(this._sprg.prog, vShader);
        Gl.attachShader(this._sprg.prog, fShader);
        Gl.linkProgram(this._sprg.prog);
		
        if (Gl.getProgramParameter(this._sprg.prog, GL.LINK_STATUS) == 0) {
            trace("Could not initialise shaders");
        }

        Gl.useProgram(this._sprg.prog);
		
        this._sprg.vpa		= Gl.getAttribLocation(this._sprg.prog, "verPos");
        this._sprg.tca		= Gl.getAttribLocation(this._sprg.prog, "texPos");
        Gl.enableVertexAttribArray(this._sprg.tca);
        Gl.enableVertexAttribArray(this._sprg.vpa);
		
		this._sprg.tMatUniform		= Gl.getUniformLocation(this._sprg.prog, "tMat");
		this._sprg.cMatUniform		= Gl.getUniformLocation(this._sprg.prog, "cMat");
		this._sprg.cVecUniform		= Gl.getUniformLocation(this._sprg.prog, "cVec");
        this._sprg.samplerUniform	= Gl.getUniformLocation(this._sprg.prog, "uSampler");
		this._sprg.useTex			= Gl.getUniformLocation(this._sprg.prog, "useTex");
		this._sprg.color			= Gl.getUniformLocation(this._sprg.prog, "color");
    }
	
    private function _initBuffers() {
        this._unitIBuffer = Gl.createBuffer();
		
		_setEBF(this._unitIBuffer);
        Gl.bufferData(GL.ELEMENT_ARRAY_BUFFER, new UInt16Array([0, 1, 2, 1, 2, 3]), GL.STATIC_DRAW);
    }
	
	public function _setFramebuffer(fbo:GLFramebuffer, w:Int, h:Int, flip:Bool) {
		this._mstack.clear();
		
		this._mstack.push(this._pmat);
		if (flip) { 
			this._umat[5]  =  2; 
			this._umat[13] = -1;
		}
		else { 
			this._umat[5]  = -2; 
			this._umat[13] =  1;
		}
		this._mstack.push(this._umat);
		
		this._smat[0] = 1 / w;  
		this._smat[5] = 1 / h;
		this._mstack.push(this._smat);

        Gl.bindFramebuffer(GL.FRAMEBUFFER, fbo);
		if (fbo != null) {
            Gl.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT16, w, h);
		}
        Gl.viewport(0, 0, w, h);
	}
	
	private function _setStageMouse(x:Int, y:Int) {	// event, want X
		var dpr = this._getDPR();
		this._mouseX = Std.int(x * dpr);
		this._mouseY = Std.int(y * dpr);
	}
	
	var lastProgram:Dynamic;
	var lastElementArrayBuffer:Dynamic;
	var lastArrayBuffer:Dynamic;
	var lastTexture:Dynamic;
	var lastEnableDepthTest:Bool;
	var lastEnableBlend:Bool;
	var lastCullEnabled:Bool;
	private function _backupGLState() {
		this.lastProgram = Gl.getParameter(GL.CURRENT_PROGRAM);
		this.lastElementArrayBuffer = Gl.getParameter(GL.ELEMENT_ARRAY_BUFFER_BINDING);
		this.lastArrayBuffer = Gl.getParameter(GL.ARRAY_BUFFER_BINDING);
		this.lastTexture = Gl.getParameter(GL.TEXTURE_BINDING_2D);
		this.lastEnableDepthTest = Gl.isEnabled(GL.DEPTH_TEST);
		this.lastEnableBlend = Gl.isEnabled(GL.BLEND);
		this.lastCullEnabled = Gl.isEnabled(GL.CULL_FACE);
	}
	
	private function _restoreGLState() {
        Gl.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, this.lastElementArrayBuffer);
        Gl.bindBuffer(GL.ARRAY_BUFFER, this.lastArrayBuffer);
        Gl.useProgram(this.lastProgram);
		
		if (this.lastTexture != null) {
            Gl.bindTexture(GL.TEXTURE_2D, this.lastTexture);
		}
		
		if (this.lastEnableDepthTest) {
            Gl.enable(GL.DEPTH_TEST);
		}
		else {
            Gl.disable(GL.DEPTH_TEST);
		}
		if (this.lastEnableBlend) {
            Gl.enable(GL.BLEND);
		}
		else {
            Gl.disable(GL.BLEND);
		}
		if (this.lastCullEnabled) {
            Gl.enable(GL.CULL_FACE);
		}
		else {
            Gl.disable(GL.CULL_FACE);
		}
	}

    private function _drawScene() {	
		//_backupGLState();
		
        Gl.enable(GL.BLEND);
		/*Gl.blendEquation(GL.FUNC_ADD);
		Gl.blendFunc(GL.ONE, GL.ONE_MINUS_SRC_ALPHA);*/
		
        Gl.enable(GL.DEPTH_TEST);
        Gl.depthFunc(GL.LEQUAL);
        Gl.disable(GL.STENCIL_TEST);
        Gl.disable(GL.CULL_FACE);
		
        Gl.useProgram(this._sprg.prog);
		
		//	proceeding EnterFrame
		var efs = EventDispatcher.efbc;
		var ev = new Event(Event.ENTER_FRAME, false);
		for(i in 0...efs.length) {
			ev.target = efs[i];
			efs[i].dispatchEvent(ev);
		}
		
        this._renderAll();
		
		//_restoreGLState();
    }
	
	private function _processMouseTouch() {
		if (this._knM) {
			var org = this._svec4_0;
			this._getOrigin(org);
			var p   = this._svec4_1;
			p[0] = this._mouseX;
			p[1] = this._mouseY;  
			p[2] = 0;  
			p[3] = 1;
			
			//	proceeding Mouse Events
			var newf = this._getTarget(org, p);
			var fa = this._mousefocus != null ? this._mousefocus : this;
			var fb = newf != null ? newf : this;
			
			if(newf != this._mousefocus) {
				if(fa != this) {
					var ev = new MouseEvent(MouseEvent.MOUSE_OUT, true);
					ev.target = fa;
					fa.dispatchEvent(ev);
				}
				if(fb != this) {
					var ev = new MouseEvent(MouseEvent.MOUSE_OVER, true);
					ev.target = fb;
					fb.dispatchEvent(ev);
				}
			}
			
			if (this._smd[0] && this.focus != null && newf != this.focus) {
				this.focus._loseFocus();
			}
			
			for (i in 0...3) {
				this._mcEvs[i].target = this._mdEvs[i].target = this._muEvs[i].target = fb;
				if (this._smd[i]) {
					fb.dispatchEvent(this._mdEvs[i]); 
					this._focii[i] = this.focus = newf;
				}
				
				if (this._smu[i]) {
					fb.dispatchEvent(this._muEvs[i]); 
					if (newf == this._focii[i]) {
						fb.dispatchEvent(this._mcEvs[i]); 
					}
				}
				this._smd[i] = this._smu[i] = false;
			}
			
			if (this._smm) { 
				var ev = new MouseEvent(MouseEvent.MOUSE_MOVE, true); 
				ev.target = fb;  
				fb.dispatchEvent(ev);  
				this._smm = false;
			}
			
			this._mousefocus = newf;
			
			//	checking buttonMode
			var uh = false;
			var ob = fb;
			while (ob.parent != null) {
				uh = cast(ob, InteractiveObject).buttonMode; 
				ob = ob.parent;
			}
			/*var cursor = uh?"pointer":"default";
			if(fb instanceof TextField && fb.selectable) cursor = "text"
			this._canvas.style.cursor = cursor;*/
		}
		
		var dpr = this._getDPR();
		for(tind in this._touches) {
			var t = this._touches[tind];
			if (t.act == 0) {
				continue;
			}
			
			var org = this._svec4_0;
			this._getOrigin(org);
			var p = this._svec4_1;
			p[0] = t.touch.clientX * dpr;  
			p[1] = t.touch.clientY * dpr;  
			p[2] = 0;  
			p[3] = 1;
			
			var newf = this._getTarget(org, p);
			var fa:Stage = t.target != null ? t.target : this;
			var fb = newf != null ? newf : this;
			
			if(newf != t.target) {
				if(fa != this) {
					var ev = new TouchEvent(TouchEvent.TOUCH_OUT, true);
					ev._setFromDom(t.touch);
					ev.target = fa;
					fa.dispatchEvent(ev);
				}
				if(fb != this) {
					var ev = new TouchEvent(TouchEvent.TOUCH_OVER, true);
					ev._setFromDom(t.touch);
					ev.target = fb;
					fb.dispatchEvent(ev);
				}
			}
			
			var ev:TouchEvent = null;
			if (t.act == 1) {
				ev = new TouchEvent(TouchEvent.TOUCH_BEGIN, true);
			}
			if (t.act == 2) {
				ev = new TouchEvent(TouchEvent.TOUCH_MOVE, true);
			}
			if (t.act == 3) {
				ev = new TouchEvent(TouchEvent.TOUCH_END, true);
			}
			ev._setFromDom(t.touch);
			ev.target = fb;
			fb.dispatchEvent(ev);
			if(t.act == 3 && newf == t.target) {
				ev = new TouchEvent(TouchEvent.TOUCH_TAP, true);
				ev._setFromDom(t.touch);
				ev.target = fb;
				fb.dispatchEvent(ev);
			}
			t.act = 0;
			t.target = (t.act == 3) ? null : newf;
		}
	}
	
}
