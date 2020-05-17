uniform sampler2D tex;
uniform float tick;
uniform vec2 mapCoord;
uniform vec4 texCoord;
uniform float attenuation;

void main(void)
{
	float time = tick / 1000.0;
	vec2 xy = gl_TexCoord[0].xy;
//	if (xy.y <= 0.5) xy.x = xy.x + (0.5-xy.y) * sin(time + mapCoord.x / 40.0 + mapCoord.y) / 14.0;
	// if (xy.y <= 0.75) xy.x = xy.x + (0.75-xy.y) * sin(time + mapCoord.x / 40.0 + mapCoord.y) / attenuation;

	vec2 ts = texCoord.zw;
	vec2 tx = texCoord.xy;
	if (xy.y <= tx.y + 0.75 * ts.y) {
		xy.x = xy.x + (tx.y + 0.75 * ts.y - xy.y) * sin(time + mapCoord.x / (40.0) + mapCoord.y) / attenuation;
	}

//	xy.x = xy.x + (1.0-xy.y) * sin(time + mapCoord.x / 40 + mapCoord.y) / attenuation;

	xy = clamp(xy, tx, tx + ts);
	gl_FragColor = texture2D(tex, xy) * gl_Color;
}
