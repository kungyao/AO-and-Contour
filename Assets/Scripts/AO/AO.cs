using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AO : MonoBehaviour
{
    public Camera cam;
    public Material ssaoMat;
    public float radius = 1.0f;

    private List<Vector4> kernel;

    public bool doCPUAO = false;
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

    private void Update()
    {
        if (doCPUAO) AOByCPU();
    }

    void AOByCPU()
    {
        Texture2D aoMap = new Texture2D(cam.scaledPixelWidth, cam.pixelHeight);

        Matrix4x4 c2w = cam.cameraToWorldMatrix;
        float imgAspect = cam.aspect;
        float tanAlpha = Mathf.Tan(cam.fieldOfView / 2 * Mathf.PI / 180.0f);
        Vector3 eyePos = cam.transform.position;
        for (int i = 0; i < cam.scaledPixelWidth; i++)
        {
            // screen x
            float rx = (((i + 0.5f) / cam.scaledPixelWidth) * 2 - 1) * tanAlpha * imgAspect;
            for (int j = 0; j < cam.pixelHeight; j++)
            {
                // screen x
                float ry = -1 * (((j + 0.5f) / cam.pixelHeight) * 2 - 1) * tanAlpha;
                // ray direction
                // camera to world
                Vector3 rd = c2w.MultiplyVector(new Vector3(rx, ry, -1));

                // ray color
                float color = occlusion(eyePos, rd);
                aoMap.SetPixel(i, cam.pixelHeight - j, new Color(color, color, color, 1));
            }
        }
        aoMap.Apply();

        byte[] _bytes = aoMap.EncodeToPNG();
        string dirPath = Application.dataPath + "/Out/";
        if (!Directory.Exists(dirPath))
        {
            Directory.CreateDirectory(dirPath);
        }
        System.IO.File.WriteAllBytes(dirPath + "result.png", _bytes);
        doCPUAO = false;
    }

    float occlusion(Vector3 eyePos, Vector3 rayDirection)
    {
        // radius
        float occlusion = 0;
        RaycastHit hit;
        if (Physics.Raycast(eyePos, rayDirection, out hit, cam.farClipPlane))
        {
            Vector3 hitPos = hit.point;
            Vector3 normal = hit.normal;
            Quaternion ft = Quaternion.FromToRotation(Vector3.forward, normal);
            // reflectDir is forward-base direction
            foreach (Vector4 reflectDir in kernel)
            {
                Vector3 normalBaseDir = ft * reflectDir;
                if (Physics.Raycast(hitPos, normalBaseDir, out hit, radius))
                {
                    occlusion++;
                }
            }
        }

        occlusion = 1.0f - occlusion / kernel.Count;
        return occlusion;
    }

    /* https://answers.unity.com/questions/1668856/whats-the-source-code-of-quaternionfromtorotation.html
     * FromToRotation source
    public static Quaternion FromToRotation(Vector3 aFrom, Vector3 aTo)
    {
        Vector3 axis = Vector3.Cross(aFrom, aTo);
        float angle = Vector3.Angle(aFrom, aTo);
        return Quaternion.AngleAxis(angle, axis.normalized);
    }

    public static Quaternion AngleAxis(float aAngle, Vector3 aAxis)
     {
         aAxis.Normalize();
         float rad = aAngle * Mathf.Deg2Rad * 0.5f;
         aAxis *= Mathf.Sin(rad);
         return new Quaternion(aAxis.x, aAxis.y, aAxis.z, Mathf.Cos(rad));
     }
     */
    //private void OnDrawGizmos()
    //{
    //    if (kernel != null)
    //    {
    //        if (toward)
    //        {
    //            Vector3 normal = toward.position - transform.position;
    //            Gizmos.color = Color.red;
    //            Gizmos.DrawLine(transform.position, toward.position);
    //            Gizmos.color = Color.white;

    //            float theta = Vector3.Angle(Vector3.forward, normal);
    //            Quaternion ft = Quaternion.FromToRotation(Vector3.forward, normal);

    //            foreach (Vector3 reflectDir in kernel)
    //            {
    //                Vector3 rotVec = ft * reflectDir;
    //                Gizmos.DrawLine(transform.position, transform.position + rotVec);
    //            }
    //        }
    //    }
    //}

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        ssaoMat.SetFloat("_Radius", radius);
        if (useOrigin || doCPUAO)
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
