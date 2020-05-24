using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AO : MonoBehaviour
{
    public Camera cam;
    // obejct list parent
    //public GameObject objectList;
    public Material ssaoMat;

    private List<Vector4> kernel;

    public bool useOrigin = false;
    public bool useAoOnly = false;
    public bool useCompine = false;
    void Start()
    {
        cam.depthTextureMode = DepthTextureMode.DepthNormals;

        int mapSize = 64;
        // generate random noise
        kernel = new List<Vector4>();
        for (int i = 0; i < mapSize; i++)
        {
            float angle = UnityEngine.Random.Range(0.0f, 1.0f) * Mathf.PI * 2;
            float r = Mathf.Sqrt(UnityEngine.Random.Range(0.0f, 1.0f));
            Vector3 v3 = new Vector3(
                r * Mathf.Cos(angle), 
                r * Mathf.Sin(angle), 
                UnityEngine.Random.Range(0.0f, 1.0f));
            v3.Normalize();
            // v3 *= Random.Range(0.0f, 1.0f);
            //float scale = (float)i / mapSize;
            //scale = Mathf.Lerp(0.1f, 1.0f, scale * scale);
            //v3 *= scale;
            kernel.Add(v3);
        }

        Texture2D noiseMap = new Texture2D(4, 4, TextureFormat.RGBAFloat, false);
        for(int i = 0; i < 16; i++)
        {
            int px = i % 4;
            int py = i / 4;
            float angle = UnityEngine.Random.Range(0.0f, 1.0f) * Mathf.PI * 2;
            float r = Mathf.Sqrt(UnityEngine.Random.Range(0.0f, 1.0f));
            //print(px + "   "+ py); 
            noiseMap.SetPixel(px, py, new Color(
                r * Mathf.Cos(angle), 
                r * Mathf.Sin(angle), 
                0, 0));
            //noiseMap.SetPixel(px, py, new Color(
            //    UnityEngine.Random.Range(0.0f, 1.0f) * 2 - 1, 
            //    UnityEngine.Random.Range(0.0f, 1.0f) * 2 - 1, 
            //    0, 0));
            //print(noiseMap.GetPixel(px, py));
        }
        noiseMap.Apply();

        ssaoMat.SetTexture("_RandomNoise", noiseMap);
        ssaoMat.SetVectorArray("_Samples", kernel);
        ssaoMat.SetFloat("_SampleSize", mapSize);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (useOrigin)
        {
            Graphics.Blit(source, destination, ssaoMat, 0);
        }
        else
        {
            RenderTexture aoTexture = RenderTexture.GetTemporary(cam.scaledPixelWidth, cam.scaledPixelHeight, 0);
            Graphics.Blit(source, aoTexture, ssaoMat, 1);

            // source 透過相機render一次後的場景
            if (useAoOnly)
            {
                Graphics.Blit(aoTexture, destination, ssaoMat, 2);
            }
            else
            {
                RenderTexture blurTexture = RenderTexture.GetTemporary(cam.scaledPixelWidth, cam.scaledPixelHeight, 0);
                Graphics.Blit(aoTexture, blurTexture, ssaoMat, 2);
                ssaoMat.SetTexture("_AOTex", aoTexture);
                // generate ao
                Graphics.Blit(source, destination, ssaoMat, 3);
                RenderTexture.ReleaseTemporary(blurTexture);
            }

            RenderTexture.ReleaseTemporary(aoTexture);
        }
    }
}
