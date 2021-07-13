$input v_color0, v_indices, v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_texColor, 0);

void main() {
    int index = (int)v_indices[0];
    if (index == 0) {
        gl_FragColor = texture2D(s_texColor, v_texcoord0);
    } else {
        gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0);
    }
}
