using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class Postprocess : MonoBehaviour
{
    private Vignette _vignette;             

    public bool isActive = false;          //脚本生效bool变量——>可用于接收角色是否处于受击状态

    private bool isAddIntensity = true;     //暗角闪烁过程中 判断是否处于增加暗角强度值的状态
    private float timer;                    //暗角闪烁计时器
    public float timeInterval = 1f;        //暗角闪烁时间间隔     

    //public float speed = 0.02f;

    private float lerpValue;                //暗角闪烁lerp值
    
    // Start is called before the first frame update
    void Start()
    {
        VolumeProfile volumeProfile = GetComponent<Volume>().profile;
        volumeProfile.TryGet(out _vignette);
        timer = 0.0f;
        //Debug.Log(_vignette);
    }

    // Update is called once per frame
    void Update()
    {
        
        if (isActive)
        {
            //处于受击状态下 屏幕会闪动
            BeAttacked();
        }
        else
        {
            timer = 0.0f;           //修正 取消受击状态时， 计时器不为零
            isAddIntensity = true;  //修正 取消受击状态时， 闪烁lerpValue突变
            //不处于受击状态下 恢复初始强度
            RecoveryVignette();
        }
           

        Debug.Log("Intensity:" + _vignette.intensity.value);
        
    }

    public void RecoveryVignette()
    {
        float currentValue = _vignette.intensity.value;
        if ( currentValue > 0 && currentValue < 0.01)
        {
            _vignette.intensity.Override(0.0f);
            
        }
        else 
        {
            float RecoveryTimer = 0.0f;
            _vignette.intensity.Override(Mathf.Lerp(currentValue,0.0f,
                RecoveryTimer + Time.deltaTime * 2f));
        }
        
        
    }

    public void InitVignette()
    {
        _vignette.intensity.Override(0.0f);
    }
    
    public void BeAttacked()
    {
        timer += Time.deltaTime;
        lerpValue = timer / timeInterval;
        if (isAddIntensity)
        {
            float VignetteIntTemp = _vignette.intensity.value;
            
            _vignette.intensity.Override(Mathf.Lerp(0, 0.5f, lerpValue));
            if (timer >= timeInterval)
            {
                isAddIntensity = false;
                timer = 0;
            }
        }
        else
        {
            float VignetteIntTemp = _vignette.intensity.value;
            
            _vignette.intensity.Override(Mathf.Lerp(0.5f, 0f, lerpValue));
            
            if (timer >= timeInterval)
            {
                isAddIntensity = true;
                timer = 0;

            }
        }
        
    }
}
