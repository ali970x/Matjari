{
  "success": true,
  "data": [
    {
      "id": 1,
      "name": "telecom",
      "type": "category",
      "parent_id": null,
      "is_active": true,
      "children": [
        {
          "id": 2,
          "name": "alfa",
          "type": "subcategory",
          "parent_id": 1,
          "is_active": true,
          "children": [
            {
              "id": 3,
              "name": "days",
              "type": "child",
              "parent_id": 2,
              "is_active": true,
              "children": [
                {
                  "id": 4,
                  "name": "one year",
                  "type": "product",
                  "parent_id": 3,
                  "price": "10.00",
                  "flow_type": "year_order",
                  "is_active": true
                }
              ]
            },
            {
              "id": 5,
              "name": "ushare",
              "type": "child",
              "parent_id": 2,
              "is_active": true,
              "children": [
                {
                  "id": 6,
                  "name": "alfa ushare 20gb",
                  "type": "product",
                  "parent_id": 5,
                  "price": "5.00",
                  "requires_target_number": true,
                  "is_active": true
                }
              ]
            }
          ]
        },
        {
          "id": 7,
          "name": "touch",
          "type": "subcategory",
          "parent_id": 1,
          "is_active": true,
          "children": []
        }
      ]
    },
    {
      "id": 8,
      "name": "social media",
      "type": "category",
      "parent_id": null,
      "is_active": true,
      "children": [
        {
          "id": 9,
          "name": "instagram",
          "type": "subcategory",
          "parent_id": 8,
          "is_active": true,
          "children": []
        }
      ]
    }
  ]
}