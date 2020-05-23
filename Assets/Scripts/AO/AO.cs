using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AO : MonoBehaviour
{
    public Camera cam;
    // obejct list parent
    public GameObject objectList;
    // map size  = kernelSize * kernelSize
    public int kernelSize = 8;

    private Texture2D kernelMap;
    private List<Vector3> kernel;
    private List<Material> mats;
    // Start is called before the first frame update
    void Start()
    {
        // generate random noise
        kernel = new List<Vector3>();
        int mapSize = kernelSize * kernelSize;
        kernelMap = new Texture2D(kernelSize, kernelSize);

        for (int i = 0; i < mapSize; i++)
        {
            float angle = UnityEngine.Random.Range(0.0f, 1.0f) * Mathf.PI * 2;
            float r = Mathf.Sqrt(UnityEngine.Random.Range(0.0f, 1.0f));
            Vector3 v3 = new Vector3(r * Mathf.Cos(angle), r * Mathf.Sin(angle), UnityEngine.Random.Range(-1.0f, 1.0f));
            v3.Normalize();
            // v3 *= Random.Range(0.0f, 1.0f);
            float scale = (float)i / mapSize;
            scale = Mathf.Lerp(0.1f, 1.0f, scale * scale);
            v3 *= scale;
            kernel.Add(v3);

            int px = i % kernelSize;
            int py = i / kernelSize;
            kernelMap.SetPixel(px, py, new Color(v3.x, v3.y, v3.z));
        }

        // get child material under objectList
        Renderer[] renderers = objectList.transform.GetComponentsInChildren<Renderer>();
        foreach (Renderer renderer in renderers)
        {
            Material mat = renderer.sharedMaterial;
            mat.SetTexture("_RandomNoise", kernelMap);
            mats.Add(mat);
        }
        renderers = null;
        GC.Collect();
    }

    // Update is called once per frame
    void Update()
    {
        ssao();
    }

    void ssao()
    {
        // generate depthnormal texture
        GameObject tmpCamObject = GameObject.Instantiate(cam.gameObject);
        Camera tmpCam = tmpCamObject.GetComponent<Camera>();
        tmpCam.depthTextureMode = DepthTextureMode.DepthNormals;

        RenderTexture renderTexture = RenderTexture.GetTemporary(tmpCam.pixelWidth, tmpCam.pixelHeight);
        tmpCam.targetTexture = renderTexture;
        tmpCam.Render();

        // set depthnormal texture to render object
        foreach (Material mat in mats)
        {
            mat.SetTexture("_DepthNormal", renderTexture);
            //mat.SetTexture("_RandomNoise", kernelMap);
        }

        // clean temporary
        Destroy(tmpCamObject);
        RenderTexture.ReleaseTemporary(renderTexture);
    }
}
