package;

import ceramic.TilemapData;
import ceramic.Files;
import ceramic.RuntimeAssets;
import ceramic.Assets;

import utils.MapInfoParser;

using ceramic.TilemapPlugin;

class ProjectAssets extends Assets {
  public static final instance: ProjectAssets = new ProjectAssets();

  public final DATA_DIR: String = 'data';
  public final ASSETS_DIR: String = 'assets';

  public var projectLoaded: Bool = false;
  public var dataPath(get, null): String;
  public var assetsPath(get, null): String;

  var mapInfoParser: MapInfoParser;

  @event function mapInfoDataReady(mapInfo: Array<MapInfo>);

  @event function mapInfoDataError();

  function new() {
    super();
    mapInfoParser = new MapInfoParser();
    onMapInfoDataReady(this, preloadMapAssets);
  }

  function get_dataPath() {
    return '${runtimeAssets.path}/$DATA_DIR';
  }

  function get_assetsPath() {
    return '${runtimeAssets.path}/$ASSETS_DIR';
  }

  public function getMapAssetName(mapPath) {
    return '${DATA_DIR}/${mapPath}';
  }

  public function setDirectory(path: String) {
    runtimeAssets = RuntimeAssets.fromPath(path);
    loadMapInfo(path);
  }

  public function tilemapData(mapPath: String): TilemapData {
    var tilemapData = this.tilemap('$DATA_DIR/$mapPath');
    return tilemapData != null ? tilemapData : null;
  }

  public function loadMapInfo(path) {
    var mapXmlPath = '$dataPath/MapInfo.xml';

    if (Files.exists(mapXmlPath)) {
      var mapXml = Files.getContent(mapXmlPath);
      try {
        var maps = mapInfoParser.parse(mapXml);
        emitMapInfoDataReady(maps);
      } catch (error) {
        app.logger.error('Unable to parse MapInfo.xml');
        emitMapInfoDataError();
      }
    } else {
      trace('unable to find the MapInfo.xml');
    }
  }

  function preloadMapAssets(mapInfo: Array<MapInfo>) {
    for (map in mapInfo) {
      var mapPath = '$dataPath/${map.path}';
      var children = map.children;
      if (!Files.exists(mapPath)) {
        continue;
      }
      this.addTilemap('$DATA_DIR/${map.path}');
      if (children != null) {
        preloadMapAssets(children);
      }
    }
    load();
  }
}
