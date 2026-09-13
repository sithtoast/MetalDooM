import MetalKit
import simd

/// A vertical-plane BSP gives walls and billboards one painter order. Splitting
/// crossing polygons avoids the incorrect results of sorting wall centers.
struct TransparentPolygon {
    var vertices:[WorldVertex]
    let material:MaterialKey?,texture:MTLTexture?,indices:MTLTexture?,blend:Int,wall:Bool
    func replacing(_ vertices:[WorldVertex])->Self {
        Self(vertices:vertices,material:material,texture:texture,indices:indices,blend:blend,wall:wall)
    }
}
final class TranslucentWorld {
    private struct Plane {
        let a:SIMD2<Double>,direction:SIMD2<Double>
        func distance(_ vertex:WorldVertex)->Double {distance(SIMD2(Double(vertex.position.x),Double(vertex.position.z)))}
        func distance(_ p:SIMD2<Double>)->Double {let d=p-a;return direction.x*d.y-direction.y*d.x}
    }
    private indirect enum Tree {case leaf;case node(Plane,[TransparentPolygon],Tree,Tree)}
    private let tree:Tree
    init(walls:[TransparentPolygon]) throws {
        var count=0
        func build(_ polygons:[TransparentPolygon],_ depth:Int)throws->Tree {
            if polygons.isEmpty {return .leaf}
            count+=polygons.count
            guard depth<256,count<200_000 else {throw PortError("Excessive translucent wall subdivision")}
            let v=polygons[polygons.count/2].vertices
            let edges=v.indices.map{i->(SIMD2<Double>,SIMD2<Double>) in
                let a=v[i].position,b=v[(i+1)%v.count].position
                return (SIMD2(Double(a.x),Double(a.z)),SIMD2(Double(b.x-a.x),Double(b.z-a.z)))
            }
            guard let edge=edges.max(by:{simd_length_squared($0.1)<simd_length_squared($1.1)}),simd_length_squared(edge.1)>1e-12 else {throw PortError("Degenerate translucent wall")}
            let plane=Plane(a:edge.0,direction:simd_normalize(edge.1))
            var middle:[TransparentPolygon]=[],positive:[TransparentPolygon]=[],negative:[TransparentPolygon]=[]
            for p in polygons {Self.partition(p,plane:plane,middle:&middle,positive:&positive,negative:&negative)}
            return .node(plane,middle,try build(positive,depth+1),try build(negative,depth+1))
        }
        tree=try build(walls,0)
    }
    private static func partition(_ polygon:TransparentPolygon,plane:Plane,middle:inout [TransparentPolygon],positive:inout [TransparentPolygon],negative:inout [TransparentPolygon]) {
        let distances=polygon.vertices.map(plane.distance)
        let hi=distances.max()!,lo=distances.min()!
        if lo>=(-1e-5) && hi<=1e-5 {middle.append(polygon);return}
        if lo>=(-1e-5) {positive.append(polygon);return}
        if hi<=1e-5 {negative.append(polygon);return}
        var front:[WorldVertex]=[],back:[WorldVertex]=[]
        for i in polygon.vertices.indices {
            let j=(i+1)%polygon.vertices.count,a=polygon.vertices[i],b=polygon.vertices[j],da=distances[i],db=distances[j]
            if da>=0 {front.append(a)}
            if da<=0 {back.append(a)}
            if (da<0 && db>0) || (da>0 && db<0) {
                let t=Float(da/(da-db))
                let cut=WorldVertex(position:a.position+(b.position-a.position)*t,uvLight:a.uvLight+(b.uvLight-a.uvLight)*t,lighting:a.lighting)
                front.append(cut);back.append(cut)
            }
        }
        if front.count>=3 {positive.append(polygon.replacing(front))}
        if back.count>=3 {negative.append(polygon.replacing(back))}
    }
    func ordered(actors:[TransparentPolygon],camera:SIMD2<Float>,yaw:Float)throws->[TransparentPolygon] {
        let eye=SIMD2(Double(camera.x),Double(-camera.y)),forward=SIMD2(cos(yaw),-sin(yaw))
        var output:[TransparentPolygon]=[],work=0
        func depth(_ p:TransparentPolygon)->Float {let v=p.vertices[0].position;return simd_dot(SIMD2(v.x,v.z),forward)}
        func visit(_ tree:Tree,_ actors:[TransparentPolygon])throws {
            work+=actors.count;guard work<200_000 else {throw PortError("Excessive translucent actor subdivision")}
            switch tree {
            case .leaf:
                output += actors.enumerated().sorted{let a=depth($0.element),b=depth($1.element);return a==b ? $0.offset<$1.offset:a>b}.map(\.element)
            case let .node(plane,walls,positive,negative):
                var middle:[TransparentPolygon]=[],front:[TransparentPolygon]=[],back:[TransparentPolygon]=[]
                for actor in actors {Self.partition(actor,plane:plane,middle:&middle,positive:&front,negative:&back)}
                if plane.distance(eye)>=0 {
                    try visit(negative,back);output+=walls;output+=middle;try visit(positive,front)
                } else {
                    try visit(positive,front);output+=walls;output+=middle;try visit(negative,back)
                }
            }
        }
        try visit(tree,actors);return output
    }
}
