import js.Browser;
import pixi.core.text.Text in PixiCoreText;
import pixi.core.math.shapes.Rectangle;
import TextField.TextMappedModification;

import FlowFontStyle;

using DisplayObjectHelper;

class Text extends PixiCoreText {
	public var charIdx : Int = 0;
	public var orgCharIdxStart : Int = 0;
	public var orgCharIdxEnd : Int = 0;
	public var difPositionMapping : Array<Int>;
}

class PixiText extends TextField {
	private var textClip : Text = null;

	// Signalizes where we have changed any properties
	// influencing text width or height
	private var metricsChanged : Bool = false;

	public function new() {
		super();

		on("removed", function () {
			if (textClip != null) {
				destroyTextClipChildren();

				if (textClip.canvas != null && Browser.document.body.contains(textClip.canvas)) {
					Browser.document.body.removeChild(textClip.canvas);
				}

				removeChild(textClip);
				textClip.destroy({ children: true, texture: true, baseTexture: true });
				textClip = null;
			}
		});
	}

	private inline function destroyTextClipChildren() {
		var clip = textClip.children.length > 0 ? textClip.children[0] : null;

		while (clip != null) {
			if (untyped clip.canvas != null && Browser.document.body.contains(untyped clip.canvas)) {
				Browser.document.body.removeChild(untyped clip.canvas);
			}

			textClip.removeChild(clip);
			clip.destroy({ children: true, texture: true, baseTexture: true });

			clip = textClip.children.length > 0 ? textClip.children[0] : null;
		}
	}

	private inline function invalidateMetrics() {
		this.metricsChanged = true;
	}

	private function bidiDecorate(text : String) : String {
		var mark : String = "";
		if (textDirection == "ltr") mark = String.fromCharCode(0x202A) else if (textDirection == "rtl") mark = String.fromCharCode(0x202B);
		if (mark != "") return mark + text + String.fromCharCode(0x202C);
		return text;
	}

	public override function setTextAndStyle(
		text : String, fontfamily : String,
		fontsize : Float, fontweight : Int, fontslope : String,
		fillcolor : Int, fillopacity : Float, letterspacing : Float,
		backgroundcolour : Int, backgroundopacity : Float
	) : Void {

		if (this.text != text || this.fontFamily != fontfamily ||
			this.fontSize != fontsize || this.fontWeight != fontweight ||
			this.fontSlope != fontslope || this.letterSpacing != letterspacing) {

			this.invalidateMetrics();
		}

		var from_flow_style : FontStyle = FlowFontStyle.fromFlowFont(fontfamily);
		var fontStyle = fontslope != "" ? fontslope : from_flow_style.style;

		style =
			{
				fontSize : fontsize < 0.6 ? 0.6 : fontsize, // pixi crashes when size < 0.6
				fill : "#" + StringTools.hex(RenderSupportJSPixi.removeAlphaChannel(fillcolor), 6),
				letterSpacing : letterspacing,
				fontFamily : from_flow_style.family,
				fontWeight : fontweight != 400 ? "" + fontweight : from_flow_style.weight,
				fontStyle : fontStyle
			};

		metrics = untyped pixi.core.text.TextMetrics.measureFont(new pixi.core.text.TextStyle(style).toFontString());

		if (interlineSpacing != 0) {
			style.lineHeight = style.fontSize * 1.1 + interlineSpacing;
		}

		super.setTextAndStyle(text, fontfamily, fontsize, fontweight, fontslope, fillcolor, fillopacity, letterspacing, backgroundcolour, backgroundopacity);
	}

	private override function layoutText() : Void {
		if (isInput())
			removeScrollRect();
		var widthDelta = 0.0;

		makeTextClip(text, 0, style);

		textClip.x = -letterSpacing;

		if ((style.align == "center" || style.align == "right") && fieldWidth > 0) {
			if (clipWidth < fieldWidth) {
				widthDelta = fieldWidth - clipWidth;

				if (style.align == "center") {
					widthDelta = widthDelta / 2;
				}

				textClip.x += widthDelta;
			}

			clipWidth = Math.max(clipWidth, fieldWidth);
		}

		setTextBackground();
		if (isInput())
			setScrollRect(0, 0, getWidth() + widthDelta, getHeight());
	}

	private override function onInput(e : Dynamic) {
		super.onInput(e);
		invalidateMetrics();
	}

	public override function getWidth() : Float {
		return fieldWidth > 0.0 && isInput() ? fieldWidth : clipWidth;
	}

	public override function getHeight() : Float {
		return fieldHeight > 0.0 && isInput() ? fieldHeight : clipHeight;
	}

	public override function setCropWords(cropWords : Bool) : Void {
		if (this.cropWords != cropWords)
			this.invalidateMetrics();

		this.cropWords = cropWords;
		style.breakWords = cropWords;
		updateNativeWidgetStyle();
	}

	public override function setWordWrap(wordWrap : Bool) : Void {
		if (this.wordWrap != wordWrap)
			this.invalidateMetrics();

		this.wordWrap = wordWrap;
		style.wordWrap = wordWrap;
		updateNativeWidgetStyle();
	}

	public override function setTextInputType(type : String) : Void {
		super.setTextInputType(type);
		invalidateMetrics();
	}

	public override function setWidth(fieldWidth : Float) : Void {
		if (this.fieldWidth != fieldWidth)
			this.invalidateMetrics();

		this.fieldWidth = fieldWidth;
		style.wordWrapWidth = fieldWidth > 0 ? fieldWidth : 2048;
		updateNativeWidgetStyle();
	}

	public override function setInterlineSpacing(interlineSpacing : Float) : Void {
		if (this.interlineSpacing != interlineSpacing)
			this.invalidateMetrics();

		this.interlineSpacing = interlineSpacing;
		style.lineHeight = style.fontSize * 1.15 + interlineSpacing;
		updateNativeWidgetStyle();
	}

	public override function setTextDirection(direction : String) : Void {
		this.textDirection = direction;
		if (direction == "RTL" || direction == "rtl")
			style.direction = "rtl";
		else
			style.direction = "ltr";
		updateNativeWidgetStyle();
	}

	public override function setAutoAlign(autoAlign : String) : Void {
		this.autoAlign = autoAlign;
		if (autoAlign == "AutoAlignRight")
			style.align = "right";
		else if (autoAlign == "AutoAlignCenter")
			style.align = "center";
		else
			style.align = "left";
		updateNativeWidgetStyle();
	}

	private function updateClipMetrics() {
		var metrics = textClip.children.length > 0 ? textClip.getLocalBounds() : getTextClipMetrics(textClip);

		clipWidth = Math.max(metrics.width - letterSpacing * 2, 0);
		clipHeight = metrics.height;

		hitArea = new Rectangle(letterSpacing, 0, clipWidth + letterSpacing, clipHeight);
	}

	private static function checkTextLength(text : String) : Array<Array<String>> {
		var textSplit = text.split('\n');

		if (textSplit.filter(function (t) { return t.length > 1000; }).length > 0) {
			return textSplit.map(function (t) { return t.length > 1000 ? splitString(t) : [t]; });
		} else {
			return [[text]];
		}
	}

	private static function splitString(text : String) : Array<String> {
		return text.length > 1000 ? [text.substr(0, 1000)].concat(splitString(text.substr(1000))) :
			text.length > 0 ? [text] : [];
	}

	public override function getCharXPosition(charIdx: Int) : Float {
		var pos = -1.0;

		layoutText();

		for (child in children) {
			var c : Dynamic = child;
			if (c.orgCharIdxStart <= charIdx && c.orgCharIdxEnd > charIdx) {
				var text = "";
				var chridx : Int = c.orgCharIdxStart;
				for (i in 0...c.text.length) {
					if (chridx >= charIdx) break;
					chridx += 1 + Math.round(c.difPositionMapping[i]);
					text += c.text.substr(i, 1);
				}
				var mtx : Dynamic = pixi.core.text.TextMetrics.measureText(text, c.style);
				var result = c.x + mtx.width;
				if (TextField.getStringDirection(c.text) == "RTL") {
					mtx = pixi.core.text.TextMetrics.measureText(c.text, c.style);
					return c.width - result;
				}
				return result;
			}
		}
		return -1.0;
	}

	private override function makeTextClip(text : String, charIdx : Int, style : Dynamic) : Dynamic {
		var modification : TextMappedModification;
		if (isInput() && type == "password")
			modification = TextField.getBulletsString(text);
		else
			modification = TextField.getActualGlyphsString(text);
		text = modification.modified;

		var chrIdx: Int = charIdx;
		var texts = wordWrap ? [[text]] : checkTextLength(text);

		if (textClip == null) {
			textClip = createTextClip(
				new TextMappedModification(
					texts[0][0],
					modification.difPositionMapping.slice(0, texts[0][0].length)
				),
				chrIdx, style
			);
			textClip.orgCharIdxStart = chrIdx;
			textClip.orgCharIdxEnd = chrIdx + texts[0][0].length;
			for (difPos in modification.difPositionMapping) textClip.orgCharIdxEnd += difPos;
		}

		if (metricsChanged) {
			textClip.text = bidiDecorate(texts[0][0]);
			if (textClip.text != texts[0][0]) {
				textClip.difPositionMapping.unshift(-1);
				textClip.difPositionMapping.push(-1);
			}
			textClip.style = style;

			if (text == "") {
				removeChild(textClip);
			} else {
				addChild(textClip);
			}

			destroyTextClipChildren();

			if (texts.length > 1 || texts[0].length > 1) {
				var currentHeight = 0.0;

				for (line in texts) {
					var currentWidth = 0.0;
					var lineHeight = 0.0;

					for (txt in line) {
						if (txt == texts[0][0]) {
							currentWidth = textClip.getLocalBounds().width;
							lineHeight = textClip.getLocalBounds().height;
						} else {
							var newTextClip = createTextClip(
								new TextMappedModification(
									txt, modification.difPositionMapping.slice(chrIdx, txt.length)
								),
								chrIdx, style
							);
							chrIdx += txt.length;

							newTextClip.x = currentWidth;
							newTextClip.y = currentHeight;

							textClip.addChild(newTextClip);

							currentWidth += newTextClip.getLocalBounds().width;
							lineHeight = Math.max(lineHeight, newTextClip.getLocalBounds().height);
						}
					}

					chrIdx += 1;
					currentHeight += lineHeight;
				}
			}

			updateClipMetrics();
		}

		var anchorX = switch (autoAlign) {
			case "AutoAlignLeft" : 0;
			case "AutoAlignRight" : 1;
			case "AutoAlignCenter" : 0.5;
			default : textDirection == "rtl"? 1 : 0;
		};
		textClip.x = anchorX * (getWidth() - this.clipWidth);

		textClip.alpha = fillOpacity;

		metricsChanged = false;

		if (TextField.cacheTextsAsBitmap) {
			textClip.cacheAsBitmap = true;
		}

		return textClip;
	}

	private function createTextClip(textMod : TextMappedModification, chrIdx : Int, style : Dynamic) : Text {
		var textClip = new Text(textMod.modified, style);
		textClip.charIdx = chrIdx;
		textClip.difPositionMapping = textMod.difPositionMapping;
		untyped textClip._visible = true;

		// The default font smoothing on webkit (-webkit-font-smoothing = subpixel-antialiased),
		// makes the text bolder when light text is placed on a dark background.
		// "antialised" produces a lighter text, which is what we want.
		// Moreover, the css style only has any effect when the canvas element
		// is part of the DOM, so we attach the underlying PIXI canvas backend
		// and make it invisible.
		// On Firefox, the equivalent css property (-moz-osx-font-smoothing = grayscale) seems to
		// have no effect on the canvas element.
		if (RenderSupportJSPixi.Antialias && (Platform.isChrome || Platform.isSafari)) {
			untyped textClip.canvas.style.webkitFontSmoothing = "antialiased";
			textClip.canvas.style.display = "none";
			Browser.document.body.appendChild(textClip.canvas);
		}

		return textClip;
	}

	private override function getTextClipMetrics(clip : Dynamic) : Dynamic {
		return pixi.core.text.TextMetrics.measureText(clip.text, clip.style);
	}

	public override function getTextMetrics() : Array<Float> {
		if (metrics == null) {
			return super.getTextMetrics();
		} else {
			return [metrics.ascent, metrics.descent, metrics.descent];
		}
	}
}