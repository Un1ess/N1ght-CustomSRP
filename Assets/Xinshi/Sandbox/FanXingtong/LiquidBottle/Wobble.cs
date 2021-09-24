using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Wobble : MonoBehaviour
{
    private Renderer rend;

    private Vector3 lastPos;
    private Vector3 lastRot;
    private Vector3 velocity;
    private Vector3 angularVelocity;

    public float MaxWobble = 0.03f;
    public float WobbleSpeed = 1f;
    public float Recovery = 1f;
    

    private float wobbleAmountX;
    private float wobbleAmountZ;
    private float wobbleAmountToAddX;
    private float wobbleAmountToAddZ;
    private float pulse;
    private float time = 0.5f;
    
    // Start is called before the first frame update
    void Start()
    {
        rend = GetComponent<Renderer>();
    }

    // Update is called once per frame
    void Update()
    {
        time += Time.deltaTime;
        //Decrease wobble over time
        wobbleAmountToAddX = Mathf.Lerp(wobbleAmountToAddX, 0, Time.deltaTime * Recovery);
        wobbleAmountToAddZ = Mathf.Lerp(wobbleAmountToAddZ, 0, Time.deltaTime * Recovery);
        
        //make a sine wave of the decreasing wobble
        pulse = 2 * Mathf.PI * WobbleSpeed;
        wobbleAmountX =  Mathf.Clamp(wobbleAmountToAddX * Mathf.Sin(pulse * time),-3,3) / 3.0f;
        wobbleAmountZ =  Mathf.Clamp(wobbleAmountToAddZ * Mathf.Sin(pulse * time),-3,3) / 3.0f;
        
        
        //send it to the shader
        rend.material.SetFloat("_WobbleX",wobbleAmountX);
        rend.material.SetFloat("_WobbleZ",wobbleAmountZ);
        if (Mathf.Abs(wobbleAmountX) < 0.05 && Mathf.Abs(wobbleAmountZ) < 0.05)
        {
            rend.material.SetFloat("_Flow",1);
        }
        
        
        
        //velocity
        velocity = (lastPos - transform.position) / Time.deltaTime;
        angularVelocity = transform.rotation.eulerAngles - lastRot;
        
        //add clamped velocity to wobble
        wobbleAmountToAddX += Mathf.Clamp((velocity.x + (angularVelocity.z * 0.2f)) * MaxWobble, -MaxWobble, MaxWobble);
        wobbleAmountToAddZ += Mathf.Clamp((velocity.z + (angularVelocity.x * 0.2f)) * MaxWobble, -MaxWobble, MaxWobble);
        
        //Keep last position
        lastPos = transform.position;
        lastRot = transform.rotation.eulerAngles;

        //Debug.Log("wobbleAmountToAddX:"+wobbleAmountToAddX);
        //Debug.Log("Mathf.Sin(pulse * time) :"+Mathf.Sin(pulse * time));

    }
}
