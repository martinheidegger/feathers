/*
Feathers
Copyright 2012-2013 Joshua Tynjala. All Rights Reserved.

This program is free software. You can redistribute and/or modify it in
accordance with the terms of the accompanying license agreement.
*/
package feathers.core
{
	import feathers.controls.text.BitmapFontTextRenderer;
	import feathers.controls.text.StageTextTextEditor;
	import feathers.events.FeathersEventType;
	import feathers.layout.ILayoutData;
	import feathers.layout.ILayoutDisplayObject;

	import flash.errors.IllegalOperationError;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	import starling.display.DisplayObject;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.utils.MatrixUtil;

	/**
	 * Dispatched after initialize() has been called, but before the first time
	 * that draw() has been called.
	 *
	 * @eventType feathers.events.FeathersEventType.INITIALIZE
	 */
	[Event(name="initialize",type="starling.events.Event")]

	/**
	 * Dispatched when the width or height of the control changes.
	 *
	 * @eventType feathers.events.FeathersEventType.RESIZE
	 */
	[Event(name="resize",type="starling.events.Event")]

	/**
	 * Base class for all UI controls. Implements invalidation and sets up some
	 * basic template functions like <code>initialize()</code> and
	 * <code>draw()</code>.
	 */
	public class FeathersControl extends Sprite implements IFeathersControl, ILayoutDisplayObject
	{
		/**
		 * @private
		 */
		private static const HELPER_MATRIX:Matrix = new Matrix();

		/**
		 * @private
		 */
		private static const HELPER_POINT:Point = new Point();

		/**
		 * @private
		 * Meant to be constant, but the ValidationQueue needs access to
		 * Starling in its constructor, so it needs to be instantiated after
		 * Starling is initialized.
		 */
		protected static var VALIDATION_QUEUE:ValidationQueue = new ValidationQueue();

		/**
		 * Flag to indicate that everything is invalid and should be redrawn.
		 */
		public static const INVALIDATION_FLAG_ALL:String = "all";

		/**
		 * Invalidation flag to indicate that the state has changed. Used by
		 * <code>isEnabled</code>, but may be used for other control states too.
		 *
		 * @see #isEnabled
		 */
		public static const INVALIDATION_FLAG_STATE:String = "state";

		/**
		 * Invalidation flag to indicate that the dimensions of the UI control
		 * have changed.
		 */
		public static const INVALIDATION_FLAG_SIZE:String = "size";

		/**
		 * Invalidation flag to indicate that the styles or visual appearance of
		 * the UI control has changed.
		 */
		public static const INVALIDATION_FLAG_STYLES:String = "styles";

		/**
		 * Invalidation flag to indicate that the skin of the UI control has changed.
		 */
		public static const INVALIDATION_FLAG_SKIN:String = "skin";

		/**
		 * Invalidation flag to indicate that the layout of the UI control has
		 * changed.
		 */
		public static const INVALIDATION_FLAG_LAYOUT:String = "layout";

		/**
		 * Invalidation flag to indicate that the primary data displayed by the
		 * UI control has changed.
		 */
		public static const INVALIDATION_FLAG_DATA:String = "data";

		/**
		 * Invalidation flag to indicate that the scroll position of the UI
		 * control has changed.
		 */
		public static const INVALIDATION_FLAG_SCROLL:String = "scroll";

		/**
		 * Invalidation flag to indicate that the selection of the UI control
		 * has changed.
		 */
		public static const INVALIDATION_FLAG_SELECTED:String = "selected";

		/**
		 * @private
		 */
		protected static const INVALIDATION_FLAG_TEXT_RENDERER:String = "textRenderer";

		/**
		 * @private
		 */
		protected static const INVALIDATION_FLAG_TEXT_EDITOR:String = "textEditor";

		/**
		 * @private
		 */
		protected static const ILLEGAL_WIDTH_ERROR:String = "A component's width cannot be NaN.";

		/**
		 * @private
		 */
		protected static const ILLEGAL_HEIGHT_ERROR:String = "A component's height cannot be NaN.";

		/**
		 * A function used by all UI controls that support text renderers to
		 * create an ITextRenderer instance. You may replace the default
		 * function with your own, if you prefer not to use the
		 * BitmapFontTextRenderer.
		 *
		 * <p>The function is expected to have the following signature:</p>
		 * <pre>function():ITextRenderer</pre>
		 *
		 * @see http://wiki.starling-framework.org/feathers/text-renderers
		 * @see feathers.core.ITextRenderer
		 */
		public static var defaultTextRendererFactory:Function = function():ITextRenderer
		{
			return new BitmapFontTextRenderer();
		}

		/**
		 * A function used by all UI controls that support text editor to
		 * create an <code>ITextEditor</code> instance. You may replace the
		 * default function with your own, if you prefer not to use the
		 * <code>StageTextTextEditor</code>.
		 *
		 * <p>The function is expected to have the following signature:</p>
		 * <pre>function():ITextEditor</pre>
		 *
		 * @see http://wiki.starling-framework.org/feathers/text-editors
		 * @see feathers.core.ITextEditor
		 */
		public static var defaultTextEditorFactory:Function = function():ITextEditor
		{
			return new StageTextTextEditor();
		}

		/**
		 * Constructor.
		 */
		public function FeathersControl()
		{
			super();
			this.addEventListener(Event.ADDED_TO_STAGE, initialize_addedToStageHandler);
			this.addEventListener(Event.FLATTEN, feathersControl_flattenHandler);
		}

		/**
		 * @private
		 */
		protected var _nameList:TokenList = new TokenList();

		/**
		 * Contains a list of all "names" assigned to this control. Names are
		 * like classes in CSS selectors. They are a non-unique identifier that
		 * can differentiate multiple styles of the same type of UI control. A
		 * single control may have many names, and many controls can share a
		 * single name. Names may be added, removed, or toggled on the <code>nameList</code>.
		 *
		 * @see #name
		 */
		public function get nameList():TokenList
		{
			return this._nameList;
		}

		/**
		 * The concatenated <code>nameList</code>, with each name separated by
		 * spaces. Names are like classes in CSS selectors. They are a
		 * non-unique identifier that can differentiate multiple styles of the
		 * same type of UI control. A single control may have many names, and
		 * many controls can share a single name.
		 *
		 * @see #nameList
		 */
		override public function get name():String
		{
			return this._nameList.value;
		}

		/**
		 * @private
		 */
		override public function set name(value:String):void
		{
			this._nameList.value = value;
		}

		/**
		 * @private
		 */
		protected var _isQuickHitAreaEnabled:Boolean = false;

		/**
		 * Similar to mouseChildren on the classic display list. If true,
		 * children cannot dispatch touch events, but hit tests will be much
		 * faster.
		 */
		public function get isQuickHitAreaEnabled():Boolean
		{
			return this._isQuickHitAreaEnabled;
		}

		/**
		 * @private
		 */
		public function set isQuickHitAreaEnabled(value:Boolean):void
		{
			this._isQuickHitAreaEnabled = value;
		}

		/**
		 * @private
		 */
		protected var _hitArea:Rectangle = new Rectangle();

		/**
		 * @private
		 */
		protected var _isInitialized:Boolean = false;

		/**
		 * Determines if the component has been initialized yet. The
		 * <code>initialize()</code> function is called one time only, when the
		 * Feathers UI control is added to the display list for the first time.
		 */
		public function get isInitialized():Boolean
		{
			return this._isInitialized;
		}

		/**
		 * @private
		 * A flag that indicates that everything is invalid. If true, no other
		 * flags will need to be tracked.
		 */
		protected var _isAllInvalid:Boolean = false;

		/**
		 * @private
		 */
		protected var _invalidationFlags:Object = {};

		/**
		 * @private
		 */
		protected var _delayedInvalidationFlags:Object = {};

		/**
		 * @private
		 */
		protected var _isEnabled:Boolean = true;

		/**
		 * Indicates whether the control is interactive or not.
		 */
		public function get isEnabled():Boolean
		{
			return _isEnabled;
		}

		/**
		 * @private
		 */
		public function set isEnabled(value:Boolean):void
		{
			if(this._isEnabled == value)
			{
				return;
			}
			this._isEnabled = value;
			this.invalidate(INVALIDATION_FLAG_STATE);
		}

		/**
		 * The width value explicitly set by calling the width setter or
		 * setSize().
		 */
		protected var explicitWidth:Number = NaN;

		/**
		 * The final width value that should be used for layout. If the width
		 * has been explicitly set, then that value is used. If not, the actual
		 * width will be calculated automatically. Each component has different
		 * automatic sizing behavior, but it's usually based on the component's
		 * skin or content, including text or subcomponents.
		 */
		protected var actualWidth:Number = 0;

		/**
		 * The width of the component, in pixels. This could be a value that was
		 * set explicitly, or the component will automatically resize if no
		 * explicit width value is provided. Each component has a different
		 * automatic sizing behavior, but it's usually based on the component's
		 * skin or content, including text or subcomponents.
		 * 
		 * <p><strong>Note:</strong> Values of the <code>width</code> and
		 * <code>height</code> properties may not be accurate until after
		 * validation. If you are seeing <code>width</code> or <code>height</code>
		 * values of <code>0</code>, but you can see something on the screen and
		 * know that the value should be larger, it may be because you asked for
		 * the dimensions before the component had validated. Call
		 * <code>validate()</code> to tell the component to immediately redraw
		 * and calculate an accurate values for the dimensions.</p>
		 * 
		 * @see feathers.core.IFeathersControl#validate()
		 */
		override public function get width():Number
		{
			return this.actualWidth;
		}

		/**
		 * @private
		 */
		override public function set width(value:Number):void
		{
			if(this.explicitWidth == value)
			{
				return;
			}
			const valueIsNaN:Boolean = isNaN(value);
			if(valueIsNaN && isNaN(this.explicitWidth))
			{
				return;
			}
			this.explicitWidth = value;
			if(valueIsNaN)
			{
				this.actualWidth = 0;
				this.invalidate(INVALIDATION_FLAG_SIZE);
			}
			else
			{
				this.setSizeInternal(value, this.actualHeight, true);
			}
		}

		/**
		 * The height value explicitly set by calling the height setter or
		 * setSize().
		 */
		protected var explicitHeight:Number = NaN;

		/**
		 * The final height value that should be used for layout. If the height
		 * has been explicitly set, then that value is used. If not, the actual
		 * height will be calculated automatically. Each component has different
		 * automatic sizing behavior, but it's usually based on the component's
		 * skin or content, including text or subcomponents.
		 */
		protected var actualHeight:Number = 0;

		/**
		 * The height of the component, in pixels. This could be a value that
		 * was set explicitly, or the component will automatically resize if no
		 * explicit height value is provided. Each component has a different
		 * automatic sizing behavior, but it's usually based on the component's
		 * skin or content, including text or subcomponents.
		 * 
		 * <p><strong>Note:</strong> Values of the <code>width</code> and
		 * <code>height</code> properties may not be accurate until after
		 * validation. If you are seeing <code>width</code> or <code>height</code>
		 * values of <code>0</code>, but you can see something on the screen and
		 * know that the value should be larger, it may be because you asked for
		 * the dimensions before the component had validated. Call
		 * <code>validate()</code> to tell the component to immediately redraw
		 * and calculate an accurate values for the dimensions.</p>
		 * 
		 * @see feathers.core.IFeathersControl#validate()
		 */
		override public function get height():Number
		{
			return this.actualHeight;
		}

		/**
		 * @private
		 */
		override public function set height(value:Number):void
		{
			if(this.explicitHeight == value)
			{
				return;
			}
			const valueIsNaN:Boolean = isNaN(value);
			if(valueIsNaN && isNaN(this.explicitHeight))
			{
				return;
			}
			this.explicitHeight = value;
			if(valueIsNaN)
			{
				this.actualHeight = 0;
				this.invalidate(INVALIDATION_FLAG_SIZE);
			}
			else
			{
				this.setSizeInternal(this.actualWidth, value, true);
			}
		}

		/**
		 * @private
		 */
		protected var _minTouchWidth:Number = 0;

		/**
		 * If using <code>isQuickHitAreaEnabled</code>, and the hit area's
		 * width is smaller than this value, it will be expanded.
		 */
		public function get minTouchWidth():Number
		{
			return this._minTouchWidth;
		}

		/**
		 * @private
		 */
		public function set minTouchWidth(value:Number):void
		{
			if(this._minTouchWidth == value)
			{
				return;
			}
			this._minTouchWidth = value;
			this.invalidate(INVALIDATION_FLAG_SIZE);
		}

		/**
		 * @private
		 */
		protected var _minTouchHeight:Number = 0;

		/**
		 * If using <code>isQuickHitAreaEnabled</code>, and the hit area's
		 * height is smaller than this value, it will be expanded.
		 */
		public function get minTouchHeight():Number
		{
			return this._minTouchHeight;
		}

		/**
		 * @private
		 */
		public function set minTouchHeight(value:Number):void
		{
			if(this._minTouchHeight == value)
			{
				return;
			}
			this._minTouchHeight = value;
			this.invalidate(INVALIDATION_FLAG_SIZE);
		}

		/**
		 * @private
		 */
		protected var _minWidth:Number = 0;

		/**
		 * The minimum recommended width to be used for self-measurement and,
		 * optionally, by any code that is resizing this component. This value
		 * is not strictly enforced in all cases. An explicit width value that
		 * is smaller than <code>minWidth</code> may be set and will not be
		 * affected by the minimum.
		 */
		public function get minWidth():Number
		{
			return this._minWidth;
		}

		/**
		 * @private
		 */
		public function set minWidth(value:Number):void
		{
			if(this._minWidth == value)
			{
				return;
			}
			if(isNaN(value))
			{
				throw new ArgumentError("minWidth cannot be NaN");
			}
			this._minWidth = value;
			this.invalidate(INVALIDATION_FLAG_SIZE);
		}

		/**
		 * @private
		 */
		protected var _minHeight:Number = 0;

		/**
		 * The minimum recommended height to be used for self-measurement and,
		 * optionally, by any code that is resizing this component. This value
		 * is not strictly enforced in all cases. An explicit height value that
		 * is smaller than <code>minHeight</code> may be set and will not be
		 * affected by the minimum.
		 */
		public function get minHeight():Number
		{
			return this._minHeight;
		}

		/**
		 * @private
		 */
		public function set minHeight(value:Number):void
		{
			if(this._minHeight == value)
			{
				return;
			}
			if(isNaN(value))
			{
				throw new ArgumentError("minHeight cannot be NaN");
			}
			this._minHeight = value;
			this.invalidate(INVALIDATION_FLAG_SIZE);
		}

		/**
		 * @private
		 */
		protected var _maxWidth:Number = Number.POSITIVE_INFINITY;

		/**
		 * The maximum recommended width to be used for self-measurement and,
		 * optionally, by any code that is resizing this component. This value
		 * is not strictly enforced in all cases. An explicit width value that
		 * is larger than <code>maxWidth</code> may be set and will not be
		 * affected by the maximum.
		 */
		public function get maxWidth():Number
		{
			return this._maxWidth;
		}

		/**
		 * @private
		 */
		public function set maxWidth(value:Number):void
		{
			if(this._maxWidth == value)
			{
				return;
			}
			if(isNaN(value))
			{
				throw new ArgumentError("maxWidth cannot be NaN");
			}
			this._maxWidth = value;
			this.invalidate(INVALIDATION_FLAG_SIZE);
		}

		/**
		 * @private
		 */
		protected var _maxHeight:Number = Number.POSITIVE_INFINITY;

		/**
		 * The maximum recommended height to be used for self-measurement and,
		 * optionally, by any code that is resizing this component. This value
		 * is not strictly enforced in all cases. An explicit height value that
		 * is larger than <code>maxHeight</code> may be set and will not be
		 * affected by the maximum.
		 */
		public function get maxHeight():Number
		{
			return this._maxHeight;
		}

		/**
		 * @private
		 */
		public function set maxHeight(value:Number):void
		{
			if(this._maxHeight == value)
			{
				return;
			}
			if(isNaN(value))
			{
				throw new ArgumentError("maxHeight cannot be NaN");
			}
			this._maxHeight = value;
			this.invalidate(INVALIDATION_FLAG_SIZE);
		}

		/**
		 * @private
		 */
		protected var _includeInLayout:Boolean = true;

		/**
		 * @inheritDoc
		 */
		public function get includeInLayout():Boolean
		{
			return this._includeInLayout;
		}

		/**
		 * @private
		 */
		public function set includeInLayout(value:Boolean):void
		{
			if(this._includeInLayout == value)
			{
				return;
			}
			this._includeInLayout = value;
			this.dispatchEventWith(FeathersEventType.LAYOUT_DATA_CHANGE);
		}

		/**
		 * @private
		 */
		protected var _layoutData:ILayoutData;

		/**
		 * @inheritDoc
		 */
		public function get layoutData():ILayoutData
		{
			return this._layoutData;
		}

		/**
		 * @private
		 */
		public function set layoutData(value:ILayoutData):void
		{
			if(this._layoutData == value)
			{
				return;
			}
			if(this._layoutData)
			{
				this._layoutData.removeEventListener(Event.CHANGE, layoutData_changeHandler);
			}
			this._layoutData = value;
			if(this._layoutData)
			{
				this._layoutData.addEventListener(Event.CHANGE, layoutData_changeHandler);
			}
			this.dispatchEventWith(FeathersEventType.LAYOUT_DATA_CHANGE);
		}

		/**
		 * @private
		 */
		protected var _focusManager:IFocusManager;

		/**
		 * @copy feathers.core.IFocusDisplayObject#focusManager
		 */
		public function get focusManager():IFocusManager
		{
			return this._focusManager;
		}

		/**
		 * @private
		 */
		public function set focusManager(value:IFocusManager):void
		{
			if(this._focusManager == value)
			{
				return;
			}
			this._focusManager = value;
		}

		/**
		 * @private
		 */
		protected var _isFocusEnabled:Boolean = true;

		/**
		 * @copy feathers.core.IFocusDisplayObject#isFocusEnabled
		 */
		public function get isFocusEnabled():Boolean
		{
			return this._isFocusEnabled;
		}

		/**
		 * @private
		 */
		public function set isFocusEnabled(value:Boolean):void
		{
			if(this._isFocusEnabled == value)
			{
				return;
			}
			this._isFocusEnabled = value;
		}

		/**
		 * @private
		 */
		protected var _nextTabFocus:IFocusDisplayObject;

		/**
		 * @copy feathers.core.IFocusDisplayObject#nextTabFocus
		 */
		public function get nextTabFocus():IFocusDisplayObject
		{
			return this._nextTabFocus;
		}

		/**
		 * @private
		 */
		public function set nextTabFocus(value:IFocusDisplayObject):void
		{
			if(this._nextTabFocus == value)
			{
				return;
			}
			this._nextTabFocus = value;
		}

		/**
		 * @private
		 * Flag to indicate that the control is currently validating.
		 */
		protected var _isValidating:Boolean = false;

		/**
		 * @private
		 */
		protected var _invalidateCount:int = 0;

		/**
		 * @private
		 */
		public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			if(!resultRect)
			{
				resultRect = new Rectangle();
			}

			var minX:Number = Number.MAX_VALUE, maxX:Number = -Number.MAX_VALUE;
			var minY:Number = Number.MAX_VALUE, maxY:Number = -Number.MAX_VALUE;

			if (targetSpace == this) // optimization
			{
				minX = 0;
				minY = 0;
				maxX = this.actualWidth;
				maxY = this.actualHeight;
			}
			else
			{
				this.getTransformationMatrix(targetSpace, HELPER_MATRIX);

				MatrixUtil.transformCoords(HELPER_MATRIX, 0, 0, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;

				MatrixUtil.transformCoords(HELPER_MATRIX, 0, this.actualHeight, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;

				MatrixUtil.transformCoords(HELPER_MATRIX, this.actualWidth, 0, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;

				MatrixUtil.transformCoords(HELPER_MATRIX, this.actualWidth, this.actualHeight, HELPER_POINT);
				minX = minX < HELPER_POINT.x ? minX : HELPER_POINT.x;
				maxX = maxX > HELPER_POINT.x ? maxX : HELPER_POINT.x;
				minY = minY < HELPER_POINT.y ? minY : HELPER_POINT.y;
				maxY = maxY > HELPER_POINT.y ? maxY : HELPER_POINT.y;
			}

			resultRect.x = minX;
			resultRect.y = minY;
			resultRect.width  = maxX - minX;
			resultRect.height = maxY - minY;

			return resultRect;
		}

		/**
		 * @private
		 */
		override public function hitTest(localPoint:Point, forTouch:Boolean=false):DisplayObject
		{
			if(this._isQuickHitAreaEnabled)
			{
				if(forTouch && (!this.visible || !this.touchable))
				{
					return null;
				}
				const clipRect:Rectangle = this.clipRect;
				if(clipRect && !clipRect.containsPoint(localPoint))
				{
					return null;
				}
				return this._hitArea.containsPoint(localPoint) ? this : null;
			}
			return super.hitTest(localPoint, forTouch);
		}

		/**
		 * Call this function to tell the UI control that a redraw is pending.
		 * The redraw will happen immediately before Starling renders the UI
		 * control to the screen. The validation system exists to ensure that
		 * multiple properties can be set together without redrawing multiple
		 * times in between each property change.
		 * 
		 * <p>If you cannot wait until later for the validation to happen, you
		 * can call <code>validate()</code> to redraw immediately. As an example,
		 * you might want to validate immediately if you need to access the
		 * correct <code>width</code> or <code>height</code> values of the UI
		 * control, since these values are calculated during validation.</p>
		 * 
		 * @see feathers.core.FeathersControl#validate()
		 */
		public function invalidate(flag:String = INVALIDATION_FLAG_ALL):void
		{
			const isAlreadyInvalid:Boolean = this.isInvalid();
			var isAlreadyDelayedInvalid:Boolean = false;
			if(this._isValidating)
			{
				for(var otherFlag:String in this._delayedInvalidationFlags)
				{
					isAlreadyDelayedInvalid = true;
					break;
				}
			}
			if(!flag || flag == INVALIDATION_FLAG_ALL)
			{
				if(this._isValidating)
				{
					this._delayedInvalidationFlags[INVALIDATION_FLAG_ALL] = true;
				}
				else
				{
					this._isAllInvalid = true;
				}
			}
			else
			{
				if(this._isValidating)
				{
					this._delayedInvalidationFlags[flag] = true;
				}
				else if(flag != INVALIDATION_FLAG_ALL)
				{
					this._invalidationFlags[flag] = true;
				}
			}
			if(!this.stage || !this._isInitialized)
			{
				//we'll add this component to the queue later, after it has been
				//added to the stage.
				return;
			}
			if(this._isValidating)
			{
				if(isAlreadyDelayedInvalid)
				{
					return;
				}
				this._invalidateCount++;
				VALIDATION_QUEUE.addControl(this, this._invalidateCount >= 10);
				return;
			}
			if(isAlreadyInvalid)
			{
				return;
			}
			this._invalidateCount = 0;
			VALIDATION_QUEUE.addControl(this, false);
		}

		/**
		 * Immediately validates the control, which triggers a redraw, if one
		 * is pending. Validation exists to postpone redrawing a component until
		 * the last possible moment before rendering so that multiple properties
		 * can be changed at once without requiring a full redraw after each
		 * change.
		 * 
		 * <p>A component cannot validate if it does not have access to the
		 * stage and if it hasn't initialized yet. A component initializes the
		 * first time that it has been added to the stage.</p>
		 * 
		 * @see #invalidate()
		 * @see #initialize()
		 * @see feathers.events.FeathersEventType#INITIALIZE
		 */
		public function validate():void
		{
			if(!this.stage || !this._isInitialized || !this.isInvalid())
			{
				return;
			}
			if(this._isValidating)
			{
				//we were already validating, and something else told us to
				//validate. that's bad.
				VALIDATION_QUEUE.addControl(this, true);
				return;
			}
			this._isValidating = true;
			this.draw();
			for(var flag:String in this._invalidationFlags)
			{
				delete this._invalidationFlags[flag];
			}
			this._isAllInvalid = false;
			for(flag in this._delayedInvalidationFlags)
			{
				if(flag == INVALIDATION_FLAG_ALL)
				{
					this._isAllInvalid = true;
				}
				else
				{
					this._invalidationFlags[flag] = true;
				}
				delete this._delayedInvalidationFlags[flag];
			}
			this._isValidating = false;
		}

		/**
		 * Indicates whether the control is pending validation or not. By
		 * default, returns <code>true</code> if any invalidation flag has been
		 * set. If you pass in a specific flag, returns <code>true</code> only
		 * if that flag has been set (others may be set too, but it checks the
		 * specific flag only. If all flags have been marked as invalid, always
		 * returns <code>true</code>.
		 */
		public function isInvalid(flag:String = null):Boolean
		{
			if(this._isAllInvalid)
			{
				return true;
			}
			if(!flag) //return true if any flag is set
			{
				for(flag in this._invalidationFlags)
				{
					return true;
				}
				return false;
			}
			return this._invalidationFlags[flag];
		}

		/**
		 * Sets both the width and the height of the control.
		 */
		public function setSize(width:Number, height:Number):void
		{
			this.explicitWidth = width;
			var widthIsNaN:Boolean = isNaN(width);
			if(widthIsNaN)
			{
				this.actualWidth = 0;
			}
			this.explicitHeight = height;
			var heightIsNaN:Boolean = isNaN(height);
			if(heightIsNaN)
			{
				this.actualHeight = 0;
			}

			if(widthIsNaN || heightIsNaN)
			{
				this.invalidate(INVALIDATION_FLAG_SIZE);
			}
			else
			{
				this.setSizeInternal(width, height, true);
			}
		}

		/**
		 * Sets the width and height of the control, with the option of
		 * invalidating or not. Intended to be used when the <code>width</code>
		 * and <code>height</code> values have not been set explicitly, and the
		 * UI control needs to measure itself and choose an "ideal" size.
		 */
		protected function setSizeInternal(width:Number, height:Number, canInvalidate:Boolean):Boolean
		{
			if(!isNaN(this.explicitWidth))
			{
				width = this.explicitWidth;
			}
			else
			{
				width = Math.min(this._maxWidth, Math.max(this._minWidth, width));
			}
			if(!isNaN(this.explicitHeight))
			{
				height = this.explicitHeight;
			}
			else
			{
				height = Math.min(this._maxHeight, Math.max(this._minHeight, height));
			}
			if(isNaN(width))
			{
				throw new ArgumentError(ILLEGAL_WIDTH_ERROR);
			}
			if(isNaN(height))
			{
				throw new ArgumentError(ILLEGAL_HEIGHT_ERROR);
			}
			var resized:Boolean = false;
			if(this.actualWidth != width)
			{
				this.actualWidth = width;
				this._hitArea.width = Math.max(width, this._minTouchWidth);
				this._hitArea.x = (this.actualWidth - this._hitArea.width) / 2;
				if(this._hitArea.x != this._hitArea.x)
				{
					this._hitArea.x = 0;
				}
				resized = true;
			}
			if(this.actualHeight != height)
			{
				this.actualHeight = height;
				this._hitArea.height = Math.max(height, this._minTouchHeight);
				this._hitArea.y = (this.actualHeight - this._hitArea.height) / 2;
				if(this._hitArea.y != this._hitArea.y)
				{
					this._hitArea.y = 0;
				}
				resized = true;
			}
			if(resized)
			{
				if(canInvalidate)
				{
					this.invalidate(INVALIDATION_FLAG_SIZE);
				}
				this.dispatchEventWith(FeathersEventType.RESIZE);
			}
			return resized;
		}

		/**
		 * Called the first time that the UI control is added to the stage, and
		 * you should override this function to customize the initialization
		 * process. Do things like create children and set up event listeners.
		 * After this function is called, <code>FeathersEventType.INITIALIZE</code>
		 * is dispatched.
		 *
		 * @see feathers.events.FeathersEventType#INITIALIZE
		 */
		protected function initialize():void
		{

		}

		/**
		 * Override to customize layout and to adjust properties of children.
		 * Called when the component validates, if any flags have been marked
		 * to indicate that validation is pending.
		 */
		protected function draw():void
		{

		}

		/**
		 * @private
		 */
		protected function feathersControl_flattenHandler(event:Event):void
		{
			if(!this.stage || !this._isInitialized)
			{
				throw new IllegalOperationError("Cannot flatten this component until it is initialized and has access to the stage.");
			}
			this.validate();
		}

		/**
		 * @private
		 * Initialize the control, if it hasn't been initialized yet. Then,
		 * invalidate.
		 */
		protected function initialize_addedToStageHandler(event:Event):void
		{
			if(event.target != this)
			{
				return;
			}
			if(!this._isInitialized)
			{
				this.initialize();
				this.invalidate(); //invalidate everything
				this._isInitialized = true;
				this.dispatchEventWith(FeathersEventType.INITIALIZE, false);
			}

			if(this.isInvalid())
			{
				this._invalidateCount = 0;
				VALIDATION_QUEUE.addControl(this, false);
			}
		}

		/**
		 * @private
		 */
		protected function layoutData_changeHandler(event:Event):void
		{
			this.dispatchEventWith(FeathersEventType.LAYOUT_DATA_CHANGE);
		}
	}
}