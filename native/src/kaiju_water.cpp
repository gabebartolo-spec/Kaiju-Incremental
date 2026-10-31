#include "kaiju_water.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <algorithm>
#include <cmath>
#include <vector>

using namespace godot;

void KaijuWater::_bind_methods() {
	ClassDB::bind_method(D_METHOD("step", "floor", "depth", "body", "flow", "nx", "r", "subs", "h", "keep", "g", "cell",
								 "rest", "open"),
			&KaijuWater::step);
}

// GDScript's maxf on two floats.
static inline double maxd(double a, double b) {
	return a > b ? a : b;
}

Array KaijuWater::step(const PackedFloat32Array &p_floor, const PackedFloat32Array &p_depth,
		const PackedFloat32Array &p_body, const PackedFloat32Array &p_flow, int64_t p_nx, const Rect2i &p_r,
		int64_t p_subs, double p_h, double p_keep, double p_g, double p_cell, double p_rest, bool p_open) {
	const int64_t n = p_floor.size();
	const bool same = p_nx > 0 && n % p_nx == 0 && p_depth.size() == n && p_body.size() == n && p_flow.size() == n * 4;
	ERR_FAIL_COND_V_MSG(!same, Array(), "KaijuWater.step: the columns differ in length");
	const int64_t nz = n / p_nx;
	const int64_t x0 = std::max<int64_t>(0, p_r.position.x);
	const int64_t y0 = std::max<int64_t>(0, p_r.position.y);
	const int64_t x1 = std::min<int64_t>(p_nx, p_r.position.x + p_r.size.x) - 1; // last column
	const int64_t y1 = std::min<int64_t>(nz, p_r.position.y + p_r.size.y) - 1;
	PackedFloat32Array depth = p_depth;
	PackedFloat32Array flow = p_flow;
	double stir = 0.0;
	if (x1 < x0 || y1 < y0) {
		Array out;
		out.push_back(depth);
		out.push_back(flow);
		out.push_back(stir);
		return out;
	}
	const float *fl = p_floor.ptr();
	const float *body = p_body.ptr();
	float *d = depth.ptrw();
	float *f = flow.ptrw();
	std::vector<float> top(fl, fl + n); // floor_y.duplicate()
	const int64_t nx = p_nx;
	for (int64_t s = 0; s < p_subs; s++) {
		// _pipes: the surface over the window
		for (int64_t j = y0; j <= y1; j++) {
			for (int64_t k = j * nx + x0; k <= j * nx + x1; k++) {
				top[k] = (float)((double)fl[k] + ((double)d[k] + (double)body[k]));
			}
		}
		// _outflow: each column's four outflows
		for (int64_t j = y0; j <= y1; j++) {
			for (int64_t i = x0; i <= x1; i++) {
				const int64_t k = j * nx + i;
				const int64_t e = k * 4;
				const double dk = d[k];
				if (dk <= 0.0) {
					f[e] = f[e + 1] = f[e + 2] = f[e + 3] = 0.0f;
					continue;
				}
				const double t = top[k];
				const double a = p_h * p_g / p_cell * dk;
				const double qr = i < x1 ? maxd(0.0, (double)f[e] * p_keep + a * (t - (double)top[k + 1])) : 0.0;
				const double ql = i > x0 ? maxd(0.0, (double)f[e + 1] * p_keep + a * (t - (double)top[k - 1])) : 0.0;
				const double qd = j < y1 ? maxd(0.0, (double)f[e + 2] * p_keep + a * (t - (double)top[k + nx])) : 0.0;
				const double qu = j > y0 ? maxd(0.0, (double)f[e + 3] * p_keep + a * (t - (double)top[k - nx])) : 0.0;
				const double out = (qr + ql + qd + qu) * p_h;
				double scale = 1.0;
				if (out > dk * p_cell) { // never more than it holds
					scale = dk * p_cell / out;
				}
				f[e] = (float)(qr * scale);
				f[e + 1] = (float)(ql * scale);
				f[e + 2] = (float)(qd * scale);
				f[e + 3] = (float)(qu * scale);
			}
		}
		// _drain: the flows into the columns
		const double gain = p_h / p_cell;
		stir = 0.0;
		for (int64_t j = y0; j <= y1; j++) {
			for (int64_t i = x0; i <= x1; i++) {
				const int64_t k = j * nx + i;
				const int64_t e = k * 4;
				double net = -((double)f[e] + (double)f[e + 1] + (double)f[e + 2] + (double)f[e + 3]);
				if (i > x0) net += (double)f[e - 4];
				if (i < x1) net += (double)f[e + 5];
				if (j > y0) net += (double)f[e - nx * 4 + 2];
				if (j < y1) net += (double)f[e + nx * 4 + 3];
				if (net == 0.0 && (double)d[k] <= 0.0) continue;
				d[k] = (float)maxd(0.0, (double)d[k] + gain * net);
				if ((double)d[k] > 0.0) {
					stir = maxd(stir, std::fabs((double)fl[k] + (double)d[k] - p_rest));
				}
			}
		}
		// _open: the mouth row runs out to sea at the wave's own speed (sqrt(g d) x its lift)
		if (p_open && y0 == 0) {
			for (int64_t k = x0; k <= x1; k++) {
				if ((double)d[k] <= 0.0) continue;
				const double lift = (double)fl[k] + (double)d[k] - p_rest;
				d[k] = (float)maxd(0.0, (double)d[k] - gain * std::sqrt(p_g * (double)d[k]) * lift);
			}
		}
	}
	Array out;
	out.push_back(depth);
	out.push_back(flow);
	out.push_back(stir);
	return out;
}
