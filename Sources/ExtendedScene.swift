import Foundation
import CryptoKit

/// Resource-only view of an explicit worker plan. This PWAD-labelled value is
/// deliberately rejected by the ordinary gameplay loader.
struct ExtendedScene {
    let resources:WAD, spriteIndices:[String:Int], spritePatches:[Int:PatchImage]
    let view:ExtendedView, geometry:Geometry, images:[MaterialKey:PixelImage], sky:PixelImage
    init(view:ExtendedView, resources:WAD) throws {
        guard let copied=view.geometry else { throw PortError("Preview requires copied geometry.") }
        let art=try Art(wad:resources)
        geometry=try Geometry(map:copied.map,textureHeights:art.textureHeights())
        var images:[MaterialKey:PixelImage]=[:]
        for key in Set(geometry.batches.map(\.material)) {
            guard let image=try art.image(key) else { throw PortError("Missing preview material: \(key.name)") }
            images[key]=image
        }
        guard let sky=try art.image(MaterialKey(name:view.sky,flat:false)) else { throw PortError("Missing preview sky: \(view.sky)") }
        var indices:[String:Int]=[:], patches:[Int:PatchImage]=[:]
        for sprite in view.presentation.actors+view.presentation.weapons {
            if indices[sprite.name] != nil { continue }
            guard let index=resources.spriteLumpIndex(sprite.name) else { throw PortError("Missing worker sprite: \(sprite.name)") }
            indices[sprite.name]=index;patches[index]=try art.patch(lump:index)
        }
        self.resources=resources;self.spriteIndices=indices;self.spritePatches=patches
        self.images=images;self.sky=sky;self.view=view
    }
}
