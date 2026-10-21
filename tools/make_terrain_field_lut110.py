"""Offline two-field RG16F LUT and conservative interpolation certificate. No GPU."""
import argparse, hashlib, json, math, time
from fractions import Fraction as F
from pathlib import Path
import numpy as np

MIN=np.array([-800.,-480.]); MAX=np.array([800.,576.]); EXTENT=MAX-MIN

def fields(x,y):
    macro=np.sin(x*.81+np.sin(y*1.17))*np.sin(y*.74)
    meadow=np.sin(x*.087+np.sin(y*.067)*1.4)*np.sin(y*.104-x*.027)
    return np.stack((macro,meadow),axis=-1)

def myy_proof():
    # M_yy=cos(A)[-b^2 sin(by)sin(cy)+2bc cos(by)cos(cy)]
    #       -sin(A)[b^2 cos(by)^2+c^2]sin(cy).
    # Treat sin/cos(cy) as a unit vector. Its 2x2 matrix has norm <=2
    # when 4I-A^T A is positive semidefinite for t=cos(by)^2 in [0,1].
    b=F(117,100);c=F(74,100);B=b*b;C=c*c
    coeff=[16-4*(B*B+C*C),4*B*B-24*B*C+4*B*C**3,-4*B*B+8*B*B*C*C,4*B**3*C]
    intervals=[]
    for left,right in [(F(0),F(1,2)),(F(1,2),F(1))]:
        q=[sum(coeff[k]*math.comb(k,j)*left**(k-j)*(right-left)**j for k in range(j,4)) for j in range(4)]
        bern=[sum(q[j]*F(math.comb(i,j),math.comb(3,j)) for j in range(i+1)) for i in range(4)]
        intervals.append({'interval':[float(left),float(right)],'bernstein_coefficients_exact':[str(v) for v in bern],'bernstein_coefficients':[float(v) for v in bern],'all_positive':all(v>0 for v in bern)})
    assert 4*B*C<4 and max(B*B+C*C,(B+C)**2)<4 and all(v['all_positive'] for v in intervals)
    return {'macro_abs_fyy_upper':2.0,'method':'Exact rational PSD certificate for 4I-A^T A, t=cos(by)^2; positive degree3 Bernstein coefficients on two intervals','intervals':intervals}

def theory(n):
    hx,hy=EXTENT/(n-1);u=2.**-24
    curvature=np.array([(.81**2*hx**2+2.*hy**2)/8,((.087+.027)**2*hx**2+((1.4*.067+.104)**2+1.4*.067**2)*hy**2)/8])
    gradient=np.array([[.81,1.17+.74],[.087+.027,1.4*.067+.104]])
    half=np.full(2,2.**-12)
    mapping=gradient@(16*u*EXTENT)
    original_f32_arithmetic=np.array([.0003,.00004])
    # The extra half-ULP allowance is deliberately larger than FP32 arithmetic.
    filter_arithmetic=np.full(2,2.**-10)
    # All later terrain rock/joint/wet factors are fixed positive multipliers.
    # For T>=.845 and dry in[0,1], |d log(ALBEDO)/d macro|<=.035/.845,
    # |d log(ALBEDO)/d meadow|<=.08*3/.92+.1/.845.
    sensitivity=np.array([.035/.845,.08*3/.92+.1/.845])
    display_per_log=255*1.055/2.4
    precision=[]
    for bits in [4,8]:
        weight=gradient@np.array([hx,hy])/(2**bits)
        error=curvature+half+mapping+original_f32_arithmetic+filter_arithmetic+weight
        lsb=display_per_log*float(sensitivity@error)
        precision.append({'subtexel_fraction_bits':bits,'bilinear_weight_quantization_field_bound':weight.tolist(),'total_field_error_bound':error.tolist(),'prequantized_display_lsb_bound':lsb,'under_one_lsb':lsb<1,
                          'intrinsic_sine_error_budget_per_call_until_1lsb':(1-lsb)/(display_per_log*float(sensitivity@np.array([3.,3.4])))})
    return {'size':n,'bytes_rg16f':n*n*4,'grid_step':[hx,hy],'second_derivative_bounds':[[.6561,2.0],[.012996,.04540944]],'bilinear_interpolation_error_bound':curvature.tolist(),'half_round_to_nearest_error_bound':half.tolist(),'float32_uv_mapping_error_bound':mapping.tolist(),'original_float32_coefficient_arithmetic_error_bound_excluding_sine_intrinsics':original_f32_arithmetic.tolist(),'filter_arithmetic_error_allowance':filter_arithmetic.tolist(),'log_albedo_sensitivity':sensitivity.tolist(),'display_lsb_per_log_albedo_error':display_per_log,'precision_cases':precision}

def sample_lut(table,points,n,bits=None):
    # Exact shader endpoint-center mapping, explicitly evaluate each step FP32.
    p=points.astype(np.float32)
    ratio=(p-MIN.astype(np.float32))/EXTENT.astype(np.float32)
    uv=(ratio*np.float32(n-1)+np.float32(.5))/np.float32(n)
    coordinates=uv.astype(np.float64)*n-.5
    coordinates=np.clip(coordinates,0,n-1)
    index=np.floor(coordinates).astype(np.int32);weight=coordinates-index
    if bits is not None:weight=np.floor(weight*(2**bits))/(2**bits)
    x=index[:,0];y=index[:,1];x1=np.minimum(x+1,n-1);y1=np.minimum(y+1,n-1)
    wx=weight[:,0,None];wy=weight[:,1,None]
    return (table[y,x].astype(np.float64)*(1-wx)+table[y,x1].astype(np.float64)*wx)*(1-wy)+(table[y1,x].astype(np.float64)*(1-wx)+table[y1,x1].astype(np.float64)*wx)*wy

def smoothstep(value):
    t=np.clip(value,0,1);return t*t*(3-2*t)

def srgb(value):
    value=np.clip(value,0,1)
    return np.where(value<=.0031308,value*12.92,1.055*np.power(value,1/2.4)-.055)

def sample_colors(values,mask,grain,base,light,spec):
    macro=values[:,0];meadow=values[:,1]
    dry=smoothstep((-meadow-.1)/.5)*mask
    ground=base*(1+dry[:,None]*np.array([.07,-.03,-.08]))
    albedo=ground*(1+.035*macro+.02*grain+.1*meadow*mask)[:,None]
    return srgb(albedo*light+spec)

def generate(n,samples):
    started=time.perf_counter();out=Path(f'.runtime/terrain_field110_{n}.rg16f');out.parent.mkdir(parents=True,exist_ok=True)
    table=np.memmap(out,dtype='<f2',mode='w+',shape=(n,n,2));xs=np.linspace(MIN[0],MAX[0],n,dtype=np.float64)[None,:]
    quant_max=np.zeros(2);quant_sumsq=np.zeros(2)
    for row in range(0,n,128):
        ys=(MIN[1]+np.arange(row,min(row+128,n),dtype=np.float64)*EXTENT[1]/(n-1))[:,None]
        exact=fields(xs,ys);half=exact.astype('<f2');table[row:row+len(ys)]=half
        residual=np.abs(half.astype(np.float64)-exact);quant_max=np.maximum(quant_max,residual.max(axis=(0,1)));quant_sumsq+=(residual*residual).sum(axis=(0,1))
    table.flush()
    h=hashlib.sha256()
    with out.open('rb') as f:
        for block in iter(lambda:f.read(8*1024*1024),b''):h.update(block)
    rng=np.random.default_rng(110)
    points=rng.uniform(MIN,MAX,size=(samples,2)).astype(np.float32).astype(np.float64)
    # Include the true low-Y side-projection boundary, all four corners and edges.
    edge=np.linspace(0,1,4096)
    points=np.concatenate([points,np.c_[MIN[0]+EXTENT[0]*edge,np.full(len(edge),MIN[1])],np.c_[MIN[0]+EXTENT[0]*edge,np.full(len(edge),MAX[1])],np.c_[np.full(len(edge),MIN[0]),MIN[1]+EXTENT[1]*edge],np.c_[np.full(len(edge),MAX[0]),MIN[1]+EXTENT[1]*edge]])
    reference=fields(points[:,0],points[:,1]);stats=[]
    # Representative analytic material colors/illumination only. Never a GPU result.
    mask=rng.uniform(0,1,len(points));grain=rng.uniform(-1,1,len(points));base=rng.uniform(.005,.8,(len(points),3));light=rng.uniform(.01,2,(len(points),3));spec=rng.uniform(0,.05,(len(points),3))
    colors=sample_colors(reference,mask,grain,base,light,spec)
    for bits in [None,4,8]:
        approximated=sample_lut(table,points,n,bits);delta=approximated-reference
        error_lsb=(sample_colors(approximated,mask,grain,base,light,spec)-colors)*255
        stats.append({'fraction_bits':'float32_uv_then_exact_weights' if bits is None else bits,'samples':len(points),'field_abs_max':np.max(np.abs(delta),axis=0).tolist(),'field_rmse':np.sqrt(np.mean(delta*delta,axis=0)).tolist(),'analytic_display_lsb_abs_max':float(np.max(np.abs(error_lsb))),'analytic_display_lsb_rmse':float(np.sqrt(np.mean(error_lsb*error_lsb))),'boundary_max_macro':float(np.max(np.abs(delta[-16384:,0]))),'boundary_max_meadow':float(np.max(np.abs(delta[-16384:,1])))})
    report={'scope':'Offline LUT data and analytic/numerical error certificate only. GPU shader/FPS/image equivalence not tested.','path':'res://'+str(out).replace('\\','/'),'absolute_path':str(out.resolve()),'width':n,'height':n,'channels':['macro','meadow'],'format':'RG16F','godot_format':'Image.FORMAT_RGH','byte_order':'little-endian float16','layout':'C contiguous [y,x,2], y index 0 corresponds p.y=-480','min':MIN.tolist(),'max':MAX.tolist(),'bytes':out.stat().st_size,'sha256':h.hexdigest(),'mipmaps':False,'sampler':'filter_linear,repeat_disable, no source_color, explicit mip0','grid':'min+i*(max-min)/(N-1), boundary included','shader_uv':'((p-min)/(max-min)*(N-1)+0.5)/N','highp_float32_uv_required':True,'out_of_domain':'Evaluate both original analytic expressions; never clamp to LUT for new terrain outside domain','quantization_all_grid_samples':{'abs_max':quant_max.tolist(),'rmse':np.sqrt(quant_sumsq/(n*n)).tolist()},'formal_derivative_proof':myy_proof(),'theory':[theory(4096),theory(8192)],'sampled_errors':stats,'formal_color_assumptions':['Original high-frequency grain, derivatives, rock, joints and shoreline functions remain byte-for-byte formulas','Float32 UV arithmetic and no sRGB decoding on LUT; filter fractional-coordinate precision >=4bits; additional half-ULP interpolation allowance included','Fixed geometry/normals/roughness/specular; diffuse is nonnegative linear in ALBEDO, independent nonnegative specular/additive light and fixed fog','Linear tonemapper followed by standard sRGB transfer/clamp, no spatial sharpening with negative weights','GPU transcendental sine approximation is not universally bounded here for original large arguments; actual frozen A/B/A must verify its residual and final framebuffer pixels'],'unverified':['GPU sample precision/device behavior','GPU performance/cache footprint','Native final-frame max/RMSE and coast/side-projection images'],'preserved':'No production shader, baker, near/far caches, original media or normal saves modified','elapsed_seconds':time.perf_counter()-started}
    Path('reports/creative110_terrain_field_lut.json').write_text(json.dumps(report,ensure_ascii=False,indent=2,allow_nan=False),encoding='utf-8')
    print(json.dumps({'path':report['path'],'bytes':report['bytes'],'sha256':report['sha256'],'sampled_errors':stats,'theory':report['theory'][0],'elapsed_seconds':report['elapsed_seconds']},ensure_ascii=True))

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--size',type=int,default=4096);parser.add_argument('--samples',type=int,default=524288);args=parser.parse_args()
    if args.size not in [4096,8192]:parser.error('Only 4096/8192 are covered by this report')
    generate(args.size,args.samples)
