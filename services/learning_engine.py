from collections import Counter
from typing import Dict, Any, List

from services.db_service import add_user_preference, get_user_preferences


class LearningEngine:
    def __init__(self, db):
        self.db = db

    def analyze_preferences(self, expenses: List[Dict[str, Any]], trips: List[Dict[str, Any]], memories: List[Dict[str, Any]]) -> Dict[str, Any]:
        preferred_categories = []
        for e in expenses:
            if category := e.get('category'):
                preferred_categories.append(category)

        category_counter = Counter(preferred_categories)

        frequent_category = category_counter.most_common(1)[0][0] if category_counter else 'general'

        visited_locations = [t.get('destination') for t in trips if t.get('destination')]
        location_counter = Counter(visited_locations)
        top_location = location_counter.most_common(1)[0][0] if location_counter else 'unknown'

        weekend_spend = 0.0
        weekday_spend = 0.0
        for e in expenses:
            amount = float(e.get('amount', 0) or 0)
            timestamp = e.get('timestamp')
            if isinstance(timestamp, str) and '-' in timestamp:
                from datetime import datetime
                try:
                    dt = datetime.fromisoformat(timestamp)
                    if dt.weekday() >= 5:
                        weekend_spend += amount
                    else:
                        weekday_spend += amount
                except Exception:
                    weekday_spend += amount
            else:
                weekday_spend += amount

        patterns = {
            'preferred_category': frequent_category,
            'preferred_location': top_location,
            'spends_more_on_weekend': weekend_spend > weekday_spend,
            'memory_count': len(memories or []),
        }

        # store basic preferences
        add_user_preference(self.db, 'preferred_category', frequent_category)
        add_user_preference(self.db, 'preferred_location', top_location)
        add_user_preference(self.db, 'spends_more_on_weekend', str(patterns['spends_more_on_weekend']))

        print('Learning engine updated user preferences')

        return {
            'preferences': {
                'category': frequent_category,
                'location': top_location,
            },
            'patterns': patterns,
        }

    def personalize_decision(self, decision: Dict[str, Any], preferences: Dict[str, Any]) -> Dict[str, Any]:
        adapted_decl = decision.get('final_decision', 'Proceed with default travel plan.')

        if preferences.get('category') == 'food':
            adapted_decl = adapted_decl + ' (Recommend more food budget and local dining options.)'

        if preferences.get('location') and preferences.get('location') != 'unknown':
            adapted_decl = adapted_decl + f" (Consider {preferences.get('location')} as preferred destination.)"

        return {
            'preferences': preferences,
            'patterns': decision.get('reasoning', {}),
            'adapted_decision': adapted_decl,
        }
