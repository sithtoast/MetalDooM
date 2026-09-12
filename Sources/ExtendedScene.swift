import Foundation

/// Immutable prepared update; its builder is confined to the worker's queue.
struct ExtendedScene {
    let resources:WAD, spriteIndices:[String:Int], spritePatches:[Int:PatchImage]
    let view:ExtendedView, copiedGeometry:ExtendedGeometry, geometry:Geometry
    let changedMaterials:Set<MaterialKey>
    let images:[MaterialKey:PixelImage], sky:PixelImage, geometryChanged:Bool
    init(view:ExtendedView,resources:WAD) throws {
        self=try ExtendedSceneBuilder(resources:resources).prepare(view)
    }
    fileprivate init(view:ExtendedView,resources:WAD,copied:ExtendedGeometry,geometry:Geometry,
                     images:[MaterialKey:PixelImage],sky:PixelImage,indices:[String:Int],patches:[Int:PatchImage],changed:Bool,changedMaterials:Set<MaterialKey>) {
        self.view=view;self.resources=resources;copiedGeometry=copied;self.geometry=geometry
        self.changedMaterials=changedMaterials;self.images=images;self.sky=sky;spriteIndices=indices;spritePatches=patches;geometryChanged=changed
    }
}

/// Reuses CPU meshes and decoded resources across updates of one fixed session.
final class ExtendedSceneBuilder {
    private let resources:WAD, art:Art, heights:[String:Float]
    private var mesh:ExtendedMesh?
    private var copied:ExtendedGeometry?, geometry:Geometry?
    private var images:[MaterialKey:PixelImage]=[:], indices:[String:Int]=[:], patches:[Int:PatchImage]=[:]
    private(set) var meshBuilds=0, imageDecodes=0, spriteDecodes=0
    init(resources:WAD) throws { self.resources=resources;art=try Art(wad:resources);heights=try art.textureHeights() }
    private func image(_ key:MaterialKey) throws -> PixelImage {
        if let image=images[key] { return image }
        guard let image=try art.image(key) else { throw PortError("Missing preview material: \(key.name)") }
        images[key]=image;imageDecodes+=1;return image
    }
    func prepare(_ view:ExtendedView) throws -> ExtendedScene {
        let changed=view.geometry != nil
        var changedMaterials=Set<MaterialKey>()
        if let update=view.geometry {
            if let copied, update.contentSHA256 != copied.contentSHA256 || update.map.name != copied.map.name { throw PortError("Preview geometry session changed.") }
            let initial=mesh == nil || !mesh!.matches(update.map)
            if initial { mesh=try ExtendedMesh(map:update.map,heights:heights);meshBuilds+=1 }
            let prepared=try mesh!.update(update.map,initial:initial)
            copied=update;geometry=prepared.0;changedMaterials=prepared.1
        }
        guard let copied, let geometry else { throw PortError("Preview requires initial geometry.") }
        for key in Set(geometry.batches.map(\.material)) {
            _=try image(key)
            if let target=view.materials.translations[key] { _=try image(target) }
        }
        let sky=try image(MaterialKey(name:view.sky,flat:false))
        for sprite in view.presentation.actors+view.presentation.weapons where indices[sprite.name]==nil {
            guard let index=resources.spriteLumpIndex(sprite.name) else { throw PortError("Missing worker sprite: \(sprite.name)") }
            indices[sprite.name]=index;patches[index]=try art.patch(lump:index);spriteDecodes+=1
        }
        return ExtendedScene(view:view,resources:resources,copied:copied,geometry:geometry,
                             images:images,sky:sky,indices:indices,patches:patches,changed:changed,changedMaterials:changedMaterials)
    }
}
