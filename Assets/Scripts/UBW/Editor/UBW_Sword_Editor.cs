using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(UBW_Sword))]
public class UBW_Sword_Editor : Editor {

    int num_sword = 300;

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        var ubw = target as UBW_Sword;
       
        int num  = EditorGUILayout.IntField("num of sword", num_sword);
        if(GUILayout.Button("Scatter"))
        {
            ubw.scatter(num);
        }

        
    }
}
