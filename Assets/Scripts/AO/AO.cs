using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AO : MonoBehaviour
{
    public Camera cam;
    // obejct list parent
    //public GameObject objectList;
    public Material renderMat;

    private List<Vector4> kernel;
    // Start is called before the first frame update
    void Start()
    {
        cam.depthTextureMode = DepthTextureMode.DepthNormals;

        // generate random noise
        kernel = new List<Vector4>();

        int kernelSize = 8;
        int mapSize = 64;
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
        }

         Texture2D noiseMap = new Texture2D(8, 8, TextureFormat.RGBAFloat, false);
        for(int i = 0; i < 16; i++)
        {
            int px = i % kernelSize;
            int py = i / kernelSize;
            float angle = UnityEngine.Random.Range(0.0f, 1.0f) * Mathf.PI * 2;
            float r = Mathf.Sqrt(UnityEngine.Random.Range(0.0f, 1.0f));
            //print(r * Mathf.Cos(angle)+"   "+ r * Mathf.Sin(angle)); 
            Vector3 noise = new Vector3(r * Mathf.Cos(angle), r * Mathf.Sin(angle), 0);
            noise.Normalize();
            noiseMap.SetPixel(px, py, new Color(noise.x, noise.y, 0));
            //print(noiseMap.GetPixel(px, py));
        }
        noiseMap.Apply();


        renderMat.SetTexture("_RandomNoise", noiseMap);
        renderMat.SetVectorArray("_Samples", kernel);
        renderMat.SetFloat("_SampleSize", mapSize);
        // get child material under objectList
        //mats = new List<Material>();
        //Renderer[] renderers = objectList.transform.GetComponentsInChildren<Renderer>();
        //foreach (Renderer renderer in renderers)
        //{
        //    Material mat = renderer.sharedMaterial;
        //    mats.Add(mat);
        //}
        //renderers = null;
        //GC.Collect();
    }

    // Update is called once per frame
    void Update()
    {
        //ssao();
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, renderMat);
        //Graphics.Blit(source, destination, mat);
        //foreach (Material mat in mats)
        //{
        //    //mat.SetTexture("_DepthNormal", _TmpTextrue);
        //    mat.SetTexture("_RandomNoise", kernelMap);
        //    mat.SetFloat("_kernelSize", kernelSize);
        //    //mat.SetTexture("_RandomNoise", kernelMap);
        //    break;
        //}
    }

    //void ssao()
    //{
    //    // generate depthnormal texture
    //    GameObject tmpCamObject = GameObject.Instantiate(cam.gameObject);
    //    Camera tmpCam = tmpCamObject.GetComponent<Camera>();
    //    tmpCam.depthTextureMode = DepthTextureMode.DepthNormals;

    //    //RenderTexture renderTexture = RenderTexture.GetTemporary(tmpCam.pixelWidth, tmpCam.pixelHeight);
    //    tmpCam.targetTexture = _TmpTextrue;
    //    tmpCam.Render();

    //    // set depthnormal texture to render object
    //    foreach (Material mat in mats)
    //    {
    //        mat.SetTexture("_DepthNormal", _TmpTextrue);
    //        mat.SetTexture("_RandomNoise", kernelMap);
    //        mat.SetFloat("_kernelSize", kernelSize);
    //        //mat.SetTexture("_RandomNoise", kernelMap);
    //    }

    //    // clean temporary
    //    Destroy(tmpCamObject);
    //    //RenderTexture.ReleaseTemporary(renderTexture);
    //}
}
