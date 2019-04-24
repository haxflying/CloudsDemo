using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(UBW_Sword))]
public class UBW_Sword_Editor : Editor {


    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        var ubw = target as UBW_Sword;
       

        if(GUILayout.Button("Scatter"))
        {
            ubw.scatter();
        }

        
    }
}
