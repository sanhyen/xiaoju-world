extends RefCounted
## A shared irregular hexahedron retains block edges instead of a faceted sphere.
static func mesh()->ArrayMesh:
	var points:=[Vector3(-0.5,-0.5,-0.5),Vector3(0.5,-0.5,-0.5),Vector3(0.5,-0.5,0.5),Vector3(-0.5,-0.5,0.5),Vector3(-0.38,0.50,-0.32),Vector3(0.31,0.37,-0.40),Vector3(0.44,0.22,0.36),Vector3(-0.33,0.33,0.40)]
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[4,5,6,7],[0,3,2,1],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		for i in [0,1,2,0,2,3]:st.add_vertex(points[face[i]])
	st.generate_normals();return st.commit()
