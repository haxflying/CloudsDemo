using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(UBW_KingsTreasure))]
public class UBW_KingsTreasure_Editor : Editor {

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        UBW_KingsTreasure kt = target as UBW_KingsTreasure;

        if(GUILayout.Button("Init"))
        {
            kt.Init();
        }

        if (GUILayout.Button("Clear"))
        {
            kt.Clear();
        }

        if (GUILayout.Button("Hide"))
        {
            kt.Hide();
        }

        if (GUILayout.Button("Active"))
        {
            kt.Active();
        }

        if (GUILayout.Button("ActiveAim"))
        {
            kt.ActiveAnim();
        }
    }
}
