const Allocator = @import("std").mem.Allocator;
const Geometry = @import("Geometry.zig");
const BufferAttribute = Geometry.BufferAttribute;

pub const cube = struct {
    pub const Config = struct {
        normals: bool = false,
        texture: bool = false,
    };

    // zig fmt: off
    pub const vertices = [_]f32{
        // Front
        -0.5, -0.5, 0.5,  
        0.5,  -0.5, 0.5,  
        0.5,  0.5,  0.5,  
        -0.5, 0.5,  0.5,  
        // Back
        -0.5, -0.5, -0.5, 
        -0.5, 0.5,  -0.5, 
        0.5,  0.5,  -0.5, 
        0.5,  -0.5, -0.5, 
        // Left
        -0.5, -0.5, -0.5, 
        -0.5, -0.5, 0.5,  
        -0.5, 0.5,  0.5,  
        -0.5, 0.5,  -0.5, 
        // Right
        0.5,  -0.5, -0.5, 
        0.5,  0.5,  -0.5, 
        0.5,  0.5,  0.5,  
        0.5,  -0.5, 0.5,  
        // Top
        -0.5, 0.5,  -0.5, 
        -0.5, 0.5,  0.5,  
        0.5,  0.5,  0.5,  
        0.5,  0.5,  -0.5, 
        // Bottom
        -0.5, -0.5, -0.5, 
        0.5,  -0.5, -0.5, 
        0.5,  -0.5, 0.5,  
        -0.5, -0.5, 0.5,  
    };

    pub const normals = [_]f32{
        // Front
        0.0, 0.0, 1.0, 
        0.0, 0.0, 1.0, 
        0.0, 0.0, 1.0, 
        0.0, 0.0, 1.0, 
        // Back                          
         0.0, 0.0, -1.0,
         0.0, 0.0, -1.0,
         0.0, 0.0, -1.0,
         0.0, 0.0, -1.0,
        // Left                          
         -1.0, 0.0, 0.0,
         -1.0, 0.0, 0.0,
         -1.0, 0.0, 0.0,
         -1.0, 0.0, 0.0,
        // Right                         
         1.0, 0.0, 0.0, 
         1.0, 0.0, 0.0, 
         1.0, 0.0, 0.0, 
         1.0, 0.0, 0.0, 
        // Top                           
         0.0, 1.0, 0.0, 
         0.0, 1.0, 0.0, 
         0.0, 1.0, 0.0, 
         0.0, 1.0, 0.0, 
        // Bottom                        
         0.0, -1.0, 0.0,
         0.0, -1.0, 0.0,
         0.0, -1.0, 0.0,
         0.0, -1.0, 0.0,
    };

    pub const texture = [_]f32{
        // Front
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
        // Back                                   
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
        0.0, 0.0,
        // Left                                   
        0.0, 0.0,
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
        // Right                                  
        1.0, 0.0,
        1.0, 1.0,
        0.0, 1.0,
        0.0, 0.0,
        // Top                                    
        0.0, 0.0,
        0.0, 1.0,
        1.0, 1.0,
        1.0, 0.0,
        // Bottom                                 
        0.0, 1.0,
        1.0, 1.0,
        1.0, 0.0,
        0.0, 0.0,
    };
    // zig fmt: on

    pub const indices = [_]u32{
        0, 1, 2, 2, 3, 0, // Back face
        4, 5, 6, 6, 7, 4, // Front face
        8, 9, 10, 10, 11, 8, // Left face
        12, 13, 14, 14, 15, 12, // Right face
        16, 17, 18, 18, 19, 16, // Bottom face
        20, 21, 22, 22, 23, 20, // Top face;
    };

    pub fn createGeometry(alloc: Allocator, comptime config: Config) Allocator.Error!Geometry {
        var geometry = Geometry.init(alloc);

        const totalAttributes: u8 = @as(u8, @intFromBool(config.normals)) + @intFromBool(config.texture);
        var data: [totalAttributes + 1]BufferAttribute = undefined;

        data[0] = .{ .name = "position", .itemSize = 3, .data = &cube.vertices };

        if (config.normals)
            data[1] = .{ .name = "normal", .itemSize = 3, .data = &cube.normals };

        if (config.texture)
            data[totalAttributes] = .{ .name = "texture", .itemSize = 2, .data = &cube.texture };

        try geometry.setVertexData(&data);
        try geometry.setIndex(&indices);

        return geometry;
    }
};
