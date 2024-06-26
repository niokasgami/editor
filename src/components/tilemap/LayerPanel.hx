package components.tilemap;

import haxe.ui.containers.Panel;
import haxe.ui.events.UIEvent;
import haxe.Timer;
import haxe.ui.components.TextField;
import haxe.ui.events.ScrollEvent;
import haxe.ui.components.CheckBox;
import haxe.ui.components.Label;
import haxe.ui.core.ItemRenderer;
import haxe.ui.events.MouseEvent;
import ceramic.TilemapLayerData;
import haxe.ui.containers.ListView;

@:build(haxe.ui.macros.ComponentMacros.ComponentMacros.build('../../assets/main/layer-panel.xml'))
class LayerPanel extends Panel {
  public var layers(default, set): Array<TilemapLayerData>;
  public var activeLayer: TilemapLayerData;

  var layerItemRenderer: LayerItemRenderer;
  
  public function new() {
    super();
    layerItemRenderer = new LayerItemRenderer();
    layerItemRenderer.id = 'layerItemRenderer';
    list.addComponent(layerItemRenderer);
    list.registerEvent(MapEvent.LAYER_VISIBILITY, onVisibleStateChange);
    list.registerEvent(UIEvent.CHANGE, onLayerSelect);
    list.registerEvent(UIEvent.PROPERTY_CHANGE, onLayerRename);
  }

  public function set_layers(layers: Array<TilemapLayerData>) {
    if (this.layers == layers) return layers;
    this.layers = layers;
    buildList();
    return layers;
  }

  function buildList() {
    if (this.layers.length < 0) return;
    list.dataSource.data = [];
    list.dataSource.allowCallbacks = false;
    var i = this.layers.length - 1;
    while (i >= 0) {
      var layer = this.layers[i];
      list.dataSource.add({
        name: layer.name,
        visibleState: layer.visible
      });
      i--;
    }
    list.dataSource.allowCallbacks = true;
  }

  function onLayerSelect(event: UIEvent) {
    var index = (this.layers.length - 1) - list.selectedIndex;
    activeLayer = this.layers[index];
    final event = new MapEvent(MapEvent.LAYER_SELECT, false, activeLayer);
    dispatch(event);
  }

  function onVisibleStateChange(event: UIEvent) {
    if (event.data != null) {
      var uiEvent = new UIEvent(MapEvent.LAYER_VISIBILITY, false, event.data);
      dispatch(uiEvent);
    }
  }

  function onLayerRename(event: UIEvent) {
    if (list.selectedItem == null) return;
    if (activeLayer != null && activeLayer.name != list.selectedItem.name) {
      var uiEvent = new UIEvent(MapEvent.LAYER_RENAME, false, list.selectedItem.name);
      dispatch(uiEvent);
    }
  }
}

private class LayerItemRenderer extends ItemRenderer {
  var label: Label;
  var textField: TextField;
  var visibleState: CheckBox;
  static var currentItemRenderer: LayerItemRenderer = null;

  public function new() {
    super();
    percentWidth = 100;
    layoutName = 'horizontal';

    label = new Label();
    label.id = 'name';
    label.percentWidth = 100;
    label.verticalAlign = 'center';

    textField = new TextField();
    textField.percentWidth = 100;
    textField.verticalAlign = 'center';
    textField.visible = false;
    textField.allowInteraction = false;

    visibleState = new CheckBox();
    visibleState.id = 'visibleState';
    visibleState.selected = false;
    visibleState.onClick = onVisibleStateClick;
    visibleState.tooltip = '{{layer.visible}}';
    visibleState.verticalAlign = 'center';

    addComponent(label);
    addComponent(textField);
    addComponent(visibleState);
  }

  public override function onReady() {
    var listView = findAncestor(ListView);
    if (listView !=  null) {
      listView.registerEvent(ScrollEvent.CHANGE, onListScroll);
    }
    registerEvent(MouseEvent.CLICK, onListViewSelect);
    registerEvent(MouseEvent.DBL_CLICK, onListViewDoubleClick);
  }

  function onListScroll(_) {
    stopEdit();
  }

  function onListViewSelect(_) {
    if (currentItemRenderer == this) return;
    if (currentItemRenderer != null) {
      currentItemRenderer.stopEdit(true);
    }
  }

  override function onDataChanged(data: Dynamic) {
    super.onDataChanged(data);
    if (data == null) return;
    var value = Reflect.field(data, label.id);
    label.text = Std.string(value);
  }

  function onVisibleStateClick(event: MouseEvent) {
    var parentList = findAncestor(ListView);
    if (parentList != null) {
      var event = new UIEvent(MapEvent.LAYER_VISIBILITY, false, {
        name: _data.name,
        visibleState: visibleState.selected
      });
      parentList.dispatch(event);
    }
  }

  function onListViewDoubleClick(event: MouseEvent) {
    if (this.hasComponentUnderPoint(event.screenX, event.screenY, CheckBox)) {
      return;
    }
    startEdit();
  }

  function startEdit() {
    if (currentItemRenderer == this) {
      return;
    }

    if (currentItemRenderer != null) {
      currentItemRenderer.stopEdit();
    }

    currentItemRenderer = this;

    label.percentWidth = 0;
    label.visible = false;

    textField.visible = true;
    textField.allowInteraction = true;
    textField.text = label.text;
    // if we focus too fast the text won't display (might be a haxeui-ceramic bug)
    Timer.delay(() -> {
      textField.focus = true;
      // we use ceramic's input directly (at least until haxeui-ceramic implements KeyboardEvents)
      input.onKeyDown(null, onKeyDown);
    }, 25);
  }

  function updateEdit() {
    if (textField != null && currentItemRenderer == this) {
      if (textField.text != label.text) {
        label.text = textField.text;
        Reflect.setField(_data, label.id, label.text);

        var parentList = findAncestor(ListView);
        if (parentList != null) {
          parentList.dataSource.update(parentList.selectedIndex, _data);
        }
      }
    }
  }

  function stopEdit(cancel: Bool = false) {
    if (textField != null && !cancel) {
      updateEdit();
    }

    currentItemRenderer = null;

    label.percentWidth = 100;
    label.visible = true;
    textField.focus = false;
    textField.visible = false;
    textField.allowInteraction = false;
    input.offKeyDown(onKeyDown);
  }

  function onKeyDown(key: ceramic.Key) {
    if (currentItemRenderer != null) {
      if (key.keyCode == ceramic.KeyCode.ENTER) {
        currentItemRenderer.stopEdit();
      } else if (key.keyCode == ceramic.KeyCode.ESCAPE) {
        currentItemRenderer.stopEdit(true);
      }
    }
  }
}