﻿package main

import "core:math/linalg"
import "core:log"
import "core:strings"

import gl "vendor:OpenGL"

import "dgl"

TriangleMesh :: struct {
    name        : strings.Builder,
    vertices    : [dynamic]Vec3,
    colors      : [dynamic]Vec4,

    uvs         : [dynamic]Vec2,

    normals     : [dynamic]Vec3,
    tangents    : [dynamic]Vec3,
    bitangents  : [dynamic]Vec3,

    submeshes   : [dynamic]SubMesh,

    // 
    pcu         : ^RenderMesh(VertexPCU),
    pcnu        : ^RenderMesh(VertexPCNU),
}

RenderMesh :: struct($VertexType: typeid) {
    vertices : [dynamic]VertexType, // VertexPCNU, VertexPCU...
    vbo   : u32,
}

TriangleIndices :: [3]u32

SubMesh :: struct {
    triangles : [dynamic]TriangleIndices,

    // OpenGL
    ebo       : u32,
    shader    : u32,
    texture    : u32, // Maybe put into material later.
}

mesh_create :: proc(name : string = "Mesh") -> ^TriangleMesh {
    mesh := new(TriangleMesh)
    strings.builder_init(&mesh.name)
    strings.write_string(&mesh.name, name)

    return mesh
}

mesh_destroy :: proc(using mesh: ^TriangleMesh) {
    mesh.vertices = nil
    
    if vertices != nil    do delete(vertices)
    if colors != nil      do delete(colors)
    if uvs != nil         do delete(uvs)
    if normals != nil     do delete(normals)
    if tangents != nil    do delete(tangents)
    if bitangents != nil  do delete(bitangents)

    if submeshes != nil {
        for submesh in &submeshes {
            if submesh.ebo != 0 do gl.DeleteBuffers(1, &submesh.ebo)
            delete(submesh.triangles)
        }
        delete(submeshes)
    }

    if pcu != nil {
        delete(pcu.vertices)
        gl.DeleteBuffers(1, &pcu.vbo)
        free(pcu)
    }
    if pcnu != nil {
        delete(pcnu.vertices)
        gl.DeleteBuffers(1, &pcnu.vbo)
        free(pcnu)
    }
    if name.buf != nil do strings.builder_destroy(&name)
}

mesh_upload :: proc(mesh: ^TriangleMesh, render_mesh_types: dgl.VertexTypes, allocator:= context.allocator) {
    context.allocator = allocator
    mesh_upload_indices(mesh)
    if .PCU  in render_mesh_types do mesh_create_pcu(mesh)
    if .PCNU in render_mesh_types do mesh_create_pcnu(mesh)
}

mesh_create_pcu :: proc(mesh: ^TriangleMesh, allocator:= context.allocator) {
    context.allocator = allocator
    length := len(mesh.vertices)
    using mesh
    {// Make mesh_pcu
        pcu = new(RenderMesh(VertexPCU))
        pcu.vertices = make([dynamic]VertexPCU, 0, length)

        has_vertices, has_color, has_normal, has_uv := 
            mesh.vertices != nil    && len(mesh.vertices) != 0, 
            mesh.colors != nil      && len(mesh.colors) != 0, 
            mesh.normals != nil     && len(mesh.normals) != 0, 
            mesh.uvs != nil         && len(mesh.uvs) != 0
            
        for i in 0..<length {
            vertex : VertexPCU
            vertex.position = mesh.vertices[i]
            vertex.color    = mesh.colors[i]    if has_color    else {1, 1, 1, 1}
            vertex.uv       = mesh.uvs[i]       if has_uv       else {0, 0}
            append(&pcu.vertices, vertex)
        }
    }
    {// Upload vbo data
        gl.GenBuffers(1, &pcu.vbo)
        gl.BindBuffer(gl.ARRAY_BUFFER, pcu.vbo)
        data_size := length * size_of(VertexPCU)
        gl.BufferData(gl.ARRAY_BUFFER, data_size, raw_data(mesh.pcu.vertices), gl.STREAM_DRAW)
    }
}
mesh_create_pcnu :: proc(mesh: ^TriangleMesh, allocator:= context.allocator) {
    context.allocator = allocator
    length := len(mesh.vertices)
    using mesh
    {// Make mesh_pcnu
        pcnu = new(RenderMesh(VertexPCNU))
        pcnu.vertices = make([dynamic]VertexPCNU, 0, length)

        has_vertices, has_color, has_normal, has_uv := 
            mesh.vertices != nil    && len(mesh.vertices) != 0, 
            mesh.colors != nil      && len(mesh.colors) != 0, 
            mesh.normals != nil     && len(mesh.normals) != 0, 
            mesh.uvs != nil         && len(mesh.uvs) != 0
            
        for i in 0..<length {
            vertex : VertexPCNU
            vertex.position = mesh.vertices[i]
            vertex.color    = mesh.colors[i]    if has_color    else {1, 1, 1, 1}
            vertex.normal   = mesh.normals[i]   if has_normal   else {0, 1, 0}
            vertex.uv       = mesh.uvs[i]       if has_uv       else {0, 0}
            append(&pcnu.vertices, vertex)
        }
    }
    {// Upload vbo data
        gl.GenBuffers(1, &pcnu.vbo)
        gl.BindBuffer(gl.ARRAY_BUFFER, pcnu.vbo)
        data_size := length * size_of(VertexPCNU)
        gl.BufferData(gl.ARRAY_BUFFER, data_size, raw_data(mesh.pcnu.vertices), gl.STREAM_DRAW)
    }
}

mesh_upload_indices :: proc(mesh: ^TriangleMesh) {
    for submesh in &mesh.submeshes {
        count := len(submesh.triangles)
        gl.GenBuffers(1, &submesh.ebo)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, submesh.ebo)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, count * size_of(TriangleIndices), raw_data(submesh.triangles), gl.STREAM_DRAW)
    }
}

mesh_make_cube :: proc(using mesh: ^TriangleMesh, shader: u32) {
    vertices  = make([dynamic]Vec3, 0, 6 * 4)
    uvs       = make([dynamic]Vec2, 0, 6 * 4)
    colors    = make([dynamic]Vec4, 0, 6 * 4)
    submeshes = make([dynamic]SubMesh)

    {// position
        a := Vec3{-1,  1, -1}
        b := Vec3{ 1,  1, -1}
        c := Vec3{-1,  1,  1}
        d := Vec3{ 1,  1,  1}
        e := Vec3{-1, -1, -1}
        f := Vec3{ 1, -1, -1}
        g := Vec3{-1, -1,  1}
        h := Vec3{ 1, -1,  1}
        append(&vertices, 
            a, b, c, d,
            c, d, g, h,
            d, b, h, f,
            b, a, f, e,
            a, c, e, g,
            g, h, e, f)
    }

    for v in &mesh.vertices do v *= 0.5

    {// uvs
        a := Vec2{0, 1}
        b := Vec2{1, 1}
        c := Vec2{0, 0}
        d := Vec2{1, 0}
        append(&uvs, 
            a, b, c, d,
            a, b, c, d, 
            a, b, c, d, 
            a, b, c, d, 
            a, b, c, d, 
            c, d, a, b)
    }

    for i in 0..<(6 * 4) do append(&colors, Vec4{1, 1, 1, 1})

    append_normal :: proc(normals: ^[dynamic]Vec3, normal: Vec3, count: u32) {
        for i in 0..<count do append(normals, normal)
    }

    append_normal(&normals, { 0,  1,  0}, 4)
    append_normal(&normals, { 0,  0,  1}, 4)
    append_normal(&normals, { 1,  0,  0}, 4)
    append_normal(&normals, { 0,  0, -1}, 4)
    append_normal(&normals, {-1,  0,  0}, 4)
    append_normal(&normals, { 0, -1,  0}, 4)

    indices := make([dynamic][3]u32, 0, 6 * 2)

    for i in 0..<6 {
        base :u32= cast(u32) i * 4
        append(&indices, 
            [3]u32{base, base + 2, base + 1}, 
            [3]u32{base + 1, base + 2, base + 3})
    }

    triangle_list : SubMesh
    triangle_list.triangles = indices
    triangle_list.shader = shader

    append(&submeshes, triangle_list)
}