package components.tilemap;

import haxe.ui.containers.ScrollView;
import ceramic.TilemapTile;
import ceramic.TilemapLayerData;
import ceramic.Point;
import renderer.GridQuad;
import ceramic.TilemapData;
import ceramic.TouchInfo;
import renderer.Grid.Cell;
import ceramic.Visual;
import ceramic.Rect;
import ceramic.Border;
import ceramic.Color;

@:build(haxe.ui.ComponentBuilder.build('../../assets/main/tilemap.xml'))
class Tilemap extends ScrollView {
  public var tilemap(default, null): ceramic.Tilemap;
  public var tilemapBackground: ceramic.Quad;
  public var tileSize: Rect = new Rect(0, 0, 16, 16);
  public var tileCursor: Border;
  public var overlay: GridQuad;
  public var activeLayer(default, set): TilemapLayerData;
  public var selectedTiles(default, set): Array<Tile>; 
  
  var tilemapTiles: Array<TilemapTile>;
  var selectionRect: Rect;
  var viewport: Visual;
  var buttonId: Int = -1;

  public function new() {
    super();
    app.screen.onPointerMove(null, onPointerMove);
  }

  function set_activeLayer(layer: TilemapLayerData) {
    if (activeLayer == layer) return layer;
    activeLayer = layer;
    var tilemapLayer = tilemap.layer(layer.name);
    overlay.size(tilemapLayer.width, tilemapLayer.height);
    overlay.shader.setVec2('resolution', tilemapLayer.width, tilemapLayer.height);
    return layer;
  }

  function set_selectedTiles(tiles: Array<Tile>) {
    if (selectedTiles == tiles) return tiles;
    tilemapTiles = [];
    for (tile in tiles) {
      tilemapTiles.push(new TilemapTile(tile.frame));
    }
    selectedTiles = tiles;
    selectionRect = overlay.grid.createRectFromCells(cast selectedTiles, tileSize);
    tileCursor.size(selectionRect.width, selectionRect.height);
    return tiles;
  }

  public override function onReady() {
    createViewport();
    createOverlay();
    createTilemapBackground();
    createTilemap();
    createTileCursor();
  }

  function createViewport() {
    viewport = new Visual();
    tilemapContainer.add(viewport);
  }

  function createOverlay() {
    overlay = new GridQuad();
    overlay.size(480, 480);
    overlay.texture = app.defaultWhiteTexture;
    overlay.shader.setVec2('resolution', overlay.width, overlay.height);
    overlay.depth = 90;
    overlay.grid.onGridClick(null, handleGridClick);
    overlay.grid.onOnGridSelection(null, handleGridPointerMove);
    viewport.add(overlay);
  }

  function createTilemapBackground() {
    tilemapBackground = new ceramic.Quad();
    tilemapBackground.color = ceramic.Color.BLACK;
    tilemapBackground.size(480, 480);
    viewport.add(tilemapBackground);
  }

  function createTilemap() {
    tilemap = new ceramic.Tilemap();
    viewport.add(tilemap);
  }

  function createTileCursor() {
    var tileSize = new Rect(0, 0, 16, 16);
    tileCursor = new Border();
    tileCursor.borderColor = Color.SNOW;
    tileCursor.borderSize = 2;
    tileCursor.size(tileSize.width, tileSize.height);
    tileCursor.depth = 99;
    viewport.add(tileCursor);
  }

  public function changeTileSize(newSize: Rect) {
    tileSize = newSize;
    tileCursor.size(tileSize.width, tileSize.height);
    overlay.grid.cellSize = newSize;
  }

  public function changeActiveMap(mapData: TilemapData) {
    if (mapData == null) return;
    loadMap(mapData);
  }

  public function resize(width, height) {
    tilemapBackground.size(width, height);
    overlay.size(width, height);
    overlay.shader.setVec2('resolution', width, height);
    tilemapContainer.width = width;
    tilemapContainer.height = height;
  }

  public function onPointerMove(info: TouchInfo) {
    if (tileCursor == null) {
      return;
    };
    var localCoords = new Point();
    viewport.screenToVisual(info.x, info.y, localCoords);

    var width = tilemap.width;
    var height = tilemap.height;
    if (localCoords.x > 0 && localCoords.y > 0 && localCoords.x < width && localCoords.y < height) {
      var x = Math.floor(localCoords.x / tileSize.width) * tileSize.width;
      var y = Math.floor(localCoords.y / tileSize.height) * tileSize.height;
      tileCursor.pos(x, y);
    }
  }

  function loadMap(mapData: TilemapData) {
    tilemap.tilemapData = mapData;
    tileSize.width = mapData.maxTileWidth;
    tileSize.height = mapData.maxTileHeight;
    resize(tilemap.width, tilemap.height);
  }

  function getActiveLayerTiles() {
    var tiles: Array<TilemapTile> = null;
    if (tilemap.tilemapData != null) {
      var layerData = tilemap.tilemapData.layer(activeLayer.name);
      var layer = tilemap.layer(activeLayer.name);
      if (layerData != null && layer != null) {
        tiles = [].concat(layerData.tiles.original);
      }
    }
    return tiles;
  }

  function updateLayerTiles(tiles: Array<TilemapTile>) {
    tilemap.tilemapData.layer(activeLayer.name).tiles = tiles;

    var layer = tilemap.layer(activeLayer.name);
    if (layer != null) layer.contentDirty = true;
  }

  function eraseTile(tilesToEdit: Array<Tile>) {
    var tiles = getActiveLayerTiles();
    if (tiles == null) return;
    for (index => tile in tilesToEdit) {
      tiles[tile.frame] = 0;
    }
    updateLayerTiles(tiles);
  }

  function drawTile(tilesToEdit: Array<Tile>) {
    var tiles = getActiveLayerTiles();
    if (tiles == null) return;

    for (index => tile in tilesToEdit) {
      var tilemapTile = tilemapTiles[index];
      if (withinTilemapBounds(tile.position.x, tile.position.y)) {
        tiles[tile.frame] = tilemapTile;
      }
    }
    updateLayerTiles(tiles);
  }

  function withinTilemapBounds(x: Float, y: Float) {
    return x >= 0 && x < tilemap.width && y >= 0 && y < tilemap.height;
  }

  function handleTilemapAction(x: Float, y: Float) {
    if (buttonId < 0) return;
    var tilesToEdit = overlay.grid.getCellsFromRect(
      new Rect(x, y, selectionRect.width, selectionRect.height)
    );

    if (buttonId == 0) {
      drawTile(tilesToEdit);
    } else if (buttonId == 2) {
      eraseTile(tilesToEdit);
    }
  }

  function handleGridPointerMove(tiles: Array<Cell>, _) {
    if (activeLayer != null && selectionRect != null) {
      handleTilemapAction(tiles[0].position.x, tiles[0].position.y);
    }
  }

  function handleGridClick (info: TouchInfo, tiles: Array<Cell>) { 
    if (activeLayer == null) return;
    var selectedTile = tiles[0];
    var tilePos = selectedTile.position;
    buttonId = info.buttonId;
    handleTilemapAction(tilePos.x, tilePos.y);
  }

  function handlePointerUp(info: TouchInfo) {
    if (info.buttonId == buttonId) {
      buttonId = -1;
    }
  }
}
