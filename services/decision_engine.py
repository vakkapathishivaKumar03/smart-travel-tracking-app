from typing import Dict, Any

from services.ai_service import generate_ai_response


class DecisionEngine:
    def __init__(self):
        self.weights = {
            'expenses': 0.30,
            'reminders': 0.25,
            'context': 0.20,
            'travel_plan': 0.15,
            'memories': 0.10,
        }

    def _score_experience(self, expense_analysis: Dict[str, Any]) -> float:
        if not expense_analysis or not isinstance(expense_analysis, dict):
            return 0.0

        total = float(expense_analysis.get('total', 0) or 0)
        breakdown = expense_analysis.get('breakdown', {})
        high_category = max(breakdown, key=breakdown.get) if breakdown else None
        high_value = float(breakdown.get(high_category, 0)) if high_category else 0

        if total == 0:
            return 0.0

        ratio = high_value / total
        return min(1.0, ratio + 0.2)

    def _score_reminders(self, reminders: Dict[str, Any]) -> float:
        if not reminders:
            return 0.0

        rum = reminders.get('reminders')
        if isinstance(rum, list) and len(rum) > 0:
            return 1.0
        return 0.0

    def _score_context(self, context: Dict[str, Any]) -> float:
        if not context:
            return 0.0

        msg = context.get('message', '') if isinstance(context, dict) else str(context)
        if 'airport' in msg.lower() or 'hotel' in msg.lower() or 'station' in msg.lower():
            return 1.0
        return 0.5

    def _score_travel_plan(self, travel_plan: Dict[str, Any]) -> float:
        if not travel_plan:
            return 0.0

        activities = travel_plan.get('activities') if isinstance(travel_plan, dict) else []
        if isinstance(activities, list) and activities:
            return min(1.0, len(activities) / 5.0)
        return 0.0

    def _score_memories(self, memories: Dict[str, Any]) -> float:
        if not memories:
            return 0.0

        if isinstance(memories, dict):
            count = sum(len(v) for v in memories.values()) if memories else 0
        elif isinstance(memories, list):
            count = len(memories)
        else:
            count = 0

        return min(1.0, count / 10.0)

    def decide(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        expense_analysis = input_data.get('expense_analysis', {})
        reminders = input_data.get('reminders', {})
        travel_plan = input_data.get('travel_plan', {})
        context = input_data.get('context', {})
        memories = input_data.get('memories', {})
        ai_insights = input_data.get('ai_insights', {})

        print('Decision engine executed')

        score = 0.0
        score += self.weights['expenses'] * self._score_experience(expense_analysis)
        score += self.weights['reminders'] * self._score_reminders(reminders)
        score += self.weights['context'] * self._score_context(context)
        score += self.weights['travel_plan'] * self._score_travel_plan(travel_plan)
        score += self.weights['memories'] * self._score_memories(memories)

        priority = 'low'
        if score >= 0.75:
            priority = 'high'
        elif score >= 0.45:
            priority = 'medium'

        rules = []
        if expense_analysis and isinstance(expense_analysis, dict):
            total = float(expense_analysis.get('total', 0) or 0)
            if total > 1000:
                rules.append('High spending detected')

        if reminders and self._score_reminders(reminders) > 0:
            rules.append('Active reminders exist')

        if context and isinstance(context, dict) and 'airport' in (context.get('message','').lower()):
            rules.append('Location indicates airport presence')

        if not rules:
            rules.append('No major signals, suggest exploration')

        final_decision = 'Proceed with default travel plan.'
        if 'High spending detected' in rules and 'Active reminders exist' in rules:
            final_decision = 'Recommend budget travel and prioritize upcoming reminders.'
        elif 'High spending detected' in rules:
            final_decision = 'Recommend tracking expenses and a budget plan.'
        elif 'Active reminders exist' in rules:
            final_decision = 'Prioritize reminders and immediate actions.'
        elif 'No major signals, suggest exploration' in rules:
            final_decision = 'Explore local area and enjoy planned activities.'

        reasoning = (' | '.join(rules) + ' | Score {:.2f}'.format(score))

        # optional AI enhancement
        try:
            combined_prompt = (
                f"Given these outputs, what is the best decision?\n"
                f"Expense: {expense_analysis}\n"
                f"Reminders: {reminders}\n"
                f"Travel plan: {travel_plan}\n"
                f"Context: {context}\n"
                f"Memories: {memories}\n"
                f"AI insights: {ai_insights}\n"
            )
            ai_recommendation = generate_ai_response(combined_prompt)
            if ai_recommendation and not ai_recommendation.startswith('AI unavailable'):
                final_decision = f"{final_decision} AI: {ai_recommendation}"
        except Exception as e:
            print(f"DecisionEngine AI fallback failed: {e}")

        return {
            'final_decision': final_decision,
            'priority': priority,
            'reasoning': reasoning,
            'agent_contributions': {
                'expense': str(expense_analysis),
                'reminder': str(reminders),
                'context': str(context),
                'travel_plan': str(travel_plan),
                'memories': str(memories),
                'ai_insights': str(ai_insights),
            },
        }
