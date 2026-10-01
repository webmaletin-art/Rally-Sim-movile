"""Aliviana los pilotos (pilot.glb y pilot_lo.glb): menos triángulos (por defecto 70 %, cuidando las costuras de UV para que no se
abran grietas) y texturas más chicas. Conserva el esqueleto, los pesos de los huesos y los nombres.
Uso: python3 slim_pilot.py [fracción de triángulos=0.70] [lado de las texturas=768]
Lee los originales de models/pilot*.glb y escribe las versiones livianas en godot/game/models/ (tools/godot/sync_assets.sh lo llama)."""
import sys, os, io, json, struct, shutil
import numpy as np, pyfqmr
from PIL import Image
from scipy.spatial import cKDTree
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(HERE, '..', '..', 'godot', 'game', 'models')
SRC = os.path.join(HERE, '..', '..', 'models')   # los originales (HTML y fuente de todo)

def read_glb(path):
    b = open(path, 'rb').read()
    jl = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack('<I', b[off:off + 4])[0]
    bin_ = b[off + 8:off + 8 + bl]
    return j, bin_

def bv_bytes(j, bin_, i):
    v = j['bufferViews'][i]
    return bin_[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]

def pad4(b, fill=b'\x00'):
    return b + fill * (-len(b) % 4)

def slim(name, frac, tex):
    src = os.path.join(SRC, name + '.glb')
    j, bin_ = read_glb(src)
    prim = j['meshes'][0]['primitives'][0]
    acc = j['accessors']
    A = prim['attributes']
    stride = j['bufferViews'][acc[A['POSITION']]['bufferView']]['byteStride']
    vb = np.frombuffer(bv_bytes(j, bin_, acc[A['POSITION']]['bufferView']), np.uint8).reshape(-1, stride)
    def col(k, dt, n):
        a = acc[A[k]]
        o = a.get('byteOffset', 0)
        return np.frombuffer(np.ascontiguousarray(vb[:, o:o + np.dtype(dt).itemsize * n]).tobytes(), dt).reshape(-1, n)
    P = col('POSITION', '<f4', 3).astype(np.float64)
    Nn = col('NORMAL', '<f4', 3)
    UV = col('TEXCOORD_0', '<f4', 2)
    JO = col('JOINTS_0', '<u2', 4)
    WE = col('WEIGHTS_0', '<f4', 4)
    F = np.frombuffer(bv_bytes(j, bin_, acc[prim['indices']]['bufferView']), '<u2').reshape(-1, 3).astype(np.int32)
    n0 = len(F)
    # islas de UV (componentes por índices compartidos)
    def comps(F, nv):
        r = np.concatenate([F[:, 0], F[:, 1]]); c = np.concatenate([F[:, 1], F[:, 2]])
        g = coo_matrix((np.ones(len(r)), (r, c)), shape=(nv, nv))
        return connected_components(g, directed=False)[1]
    isl = comps(F, len(P))
    S = pyfqmr.Simplify()
    S.setMesh(P, F)
    S.simplify_mesh(target_count=int(n0 * frac), aggressiveness=7, preserve_border=True, verbose=False)
    nv, nf, _ = S.getMesh()
    nf = nf.astype(np.int32)
    # isla de cada componente nueva: voto de sus vértices (el más cercano de la malla original)
    nisl = comps(nf, len(nv))
    used = np.zeros(len(nv), bool); used[nf.reshape(-1)] = True
    tree = cKDTree(P)
    d, ii = tree.query(nv, k=1)
    new_isl_map = {}
    for c in np.unique(nisl[used]):
        sel = np.where((nisl == c) & used)[0]
        votes = np.bincount(isl[ii[sel]])
        new_isl_map[c] = int(votes.argmax())
    out_of = np.full(len(nv), -1)
    for c, o in new_isl_map.items():
        sel = np.where((nisl == c) & used)[0]
        trees = cKDTree(P[isl == o])
        orig = np.where(isl == o)[0]
        _, k = trees.query(nv[sel], k=1)
        out_of[sel] = orig[k]
    keep = np.where(used)[0]
    remap = -np.ones(len(nv), int); remap[keep] = np.arange(len(keep))
    src_i = out_of[keep]
    nF = remap[nf]
    nP = nv[keep]
    # normales: recalculadas de la malla nueva por vértice (promedio de caras), sin mezclar costuras (cada isla tiene sus vértices)
    tri = nP[nF]
    fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    NN = np.zeros_like(nP)
    for k in range(3):
        np.add.at(NN, nF[:, k], fn)
    ln = np.linalg.norm(NN, axis=1, keepdims=True)
    NN = np.where(ln > 1e-12, NN / np.maximum(ln, 1e-12), Nn[src_i])
    # costuras: las normales de los vértices duplicados deben coincidir con las originales: se promedian con la original
    NN = NN * 0.5 + Nn[src_i].astype(np.float64) * 0.5
    NN /= np.maximum(np.linalg.norm(NN, axis=1, keepdims=True), 1e-12)
    # buffer entrelazado igual que el original
    out = np.zeros((len(nP), stride), np.uint8)
    def put(k, arr, dt):
        o = acc[A[k]].get('byteOffset', 0)
        b = np.ascontiguousarray(arr.astype(dt)).view(np.uint8).reshape(len(arr), -1)
        out[:, o:o + b.shape[1]] = b
    put('POSITION', nP, '<f4'); put('NORMAL', NN, '<f4'); put('TEXCOORD_0', UV[src_i], '<f4')
    put('JOINTS_0', JO[src_i], '<u2'); put('WEIGHTS_0', WE[src_i], '<f4')
    idx_b = nF.astype('<u2').tobytes()
    ibm = bv_bytes(j, bin_, acc[j['skins'][0]['inverseBindMatrices']]['bufferView'])
    # nuevo bin: IBM · índices · vértices · imágenes
    chunks = []
    views = []
    def add(b, **kw):
        pos = sum(len(c) for c in chunks)
        chunks.append(pad4(b))
        v = {'buffer': 0, 'byteOffset': pos, 'byteLength': len(b)}; v.update(kw)
        views.append(v)
        return len(views) - 1
    v_ibm = add(ibm)
    v_idx = add(idx_b, target=34963)
    v_vtx = add(out.tobytes(), byteStride=stride, target=34962)
    # accesores
    ac = json.loads(json.dumps(acc))
    ibm_acc = j['skins'][0]['inverseBindMatrices']
    ac[ibm_acc]['bufferView'] = v_ibm
    ac[prim['indices']]['bufferView'] = v_idx; ac[prim['indices']]['count'] = int(nF.size)
    for k in A:
        ac[A[k]]['bufferView'] = v_vtx; ac[A[k]]['count'] = int(len(nP))
    # límites de posición
    ac[A['POSITION']]['min'] = nP.min(0).tolist(); ac[A['POSITION']]['max'] = nP.max(0).tolist()
    # imágenes
    for im in j.get('images', []):
        raw = bv_bytes(j, bin_, im['bufferView'])
        img = Image.open(io.BytesIO(raw)).convert('RGB')
        img = img.resize((tex, tex), Image.LANCZOS)
        buf = io.BytesIO(); img.save(buf, 'JPEG', quality=88)
        im['bufferView'] = add(buf.getvalue())
        tag = im.get('name', '').replace('.png', '')
        for fn_ in os.listdir(MODELS):
            if fn_.startswith(name + '_') and fn_.endswith('.jpg') and tag.split('_', 1)[-1][:6] in fn_:
                pass
    j['accessors'] = ac
    j['bufferViews'] = views
    binb = b''.join(chunks)
    j['buffers'] = [{'byteLength': len(binb)}]
    jb = json.dumps(j, separators=(',', ':')).encode()
    jb += b' ' * (-len(jb) % 4)
    total = 12 + 8 + len(jb) + 8 + len(binb)
    glb = struct.pack('<III', 0x46546C67, 2, total) + struct.pack('<II', len(jb), 0x4E4F534A) + jb + struct.pack('<II', len(binb), 0x004E4942) + binb
    open(os.path.join(MODELS, name + '.glb'), 'wb').write(glb)
    print(name, 'triángulos', n0, '→', len(nF), ' vértices', len(P), '→', len(nP), ' bytes', len(glb))

if __name__ == '__main__':
    frac = float(sys.argv[1]) if len(sys.argv) > 1 else 0.70
    tex = int(sys.argv[2]) if len(sys.argv) > 2 else 768
    for n in ('pilot', 'pilot_lo'):
        slim(n, frac, tex)
    # texturas extraídas junto al GLB (Godot las usa de ahí)
    for f in os.listdir(MODELS):
        if f.startswith('pilot_') and f.endswith('.jpg'):
            p = os.path.join(MODELS, f)
            im = Image.open(p)
            if im.size[0] != tex:
                im.convert('RGB').resize((tex, tex), Image.LANCZOS).save(p, 'JPEG', quality=88)
                print(f, im.size, '→', tex)
