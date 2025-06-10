// lib/screens/chat/chat_bot_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../config/theme.dart';
import '../../models/chat_message_model.dart';
import '../../providers/ai_chat_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../config/routes.dart';
import 'dart:math' as math;

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;
  bool _showQuickActions = true;
  
  // Animaciones avanzadas
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  // Estado de interfaz
  final bool _isExpanded = false;
  final String _lastBotMessageType = '';
  
  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _initializeAnimations();
    _scrollController.addListener(_onScroll);
  }
  
  void _initializeAnimations() {
    // Animation para indicador de escritura
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _typingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _typingAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Animation para slide de acciones rápidas
    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOut,
    ));
    
    // Animation para pulso de botón de envío
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimationController.forward();
  }
  
  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    _typingAnimationController.dispose();
    _slideAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }
  
  void _onTextChanged() {
    setState(() {
      _isComposing = _messageController.text.trim().isNotEmpty;
      _showQuickActions = _messageController.text.trim().isEmpty;
    });
    
    // Animar pulso cuando hay texto
    if (_isComposing && !_pulseAnimationController.isAnimating) {
      _pulseAnimationController.repeat(reverse: true);
    } else if (!_isComposing) {
      _pulseAnimationController.stop();
      _pulseAnimationController.reset();
    }
  }
  
  void _onScroll() {
    // Ocultar acciones rápidas al hacer scroll hacia abajo
    if (_scrollController.hasClients) {
      final scrollPosition = _scrollController.position.pixels;
      final maxScroll = _scrollController.position.maxScrollExtent;
      
      if (scrollPosition > 100 && _showQuickActions && _messageController.text.isEmpty) {
        setState(() {
          _showQuickActions = false;
        });
      }
    }
  }
  
  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    _messageController.clear();
    setState(() {
      _isComposing = false;
      _showQuickActions = false;
    });
    
    _focusNode.unfocus();
    _pulseAnimationController.stop();
    _pulseAnimationController.reset();
    
    final chatProvider = Provider.of<AIChatProvider>(context, listen: false);
    await chatProvider.sendMessage(text);
    
    _scrollToBottom();
  }
  
  Future<void> _useSuggestion(String suggestionText) async {
    HapticFeedback.selectionClick();
    
    final chatProvider = Provider.of<AIChatProvider>(context, listen: false);
    await chatProvider.sendMessage(suggestionText);
    
    setState(() {
      _showQuickActions = false;
    });
    
    _scrollToBottom();
  }
  
  Future<void> _executeActionFromMessage(ChatMessage message) async {
    if (message.type != MessageType.action || message.metadata == null) {
      return;
    }
    
    HapticFeedback.mediumImpact();
    
    final actionType = message.metadata!['actionType'] as String?;
    final actionData = message.metadata!['actionData'] as Map<String, dynamic>?;

    if (actionType == 'confirm_action' && actionData != null) {
      await _showActionConfirmationDialog(actionData);
    } else {
      // Como el nuevo provider no tiene executeActionFromMessage,
      // podemos enviar el texto de la acción como un mensaje normal
      final chatProvider = Provider.of<AIChatProvider>(context, listen: false);
      final actionText = message.metadata?['action_text'] ?? 'Ejecutar acción';
      await chatProvider.sendMessage(actionText);
    }
    
    _scrollToBottom();
  }
  
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _handleQuickAction(String actionText) {
    _useSuggestion(actionText);
  }
  
  List<String> _generateSmartSuggestions(AIChatProvider chatProvider) {
    if (chatProvider.messages.isEmpty) {
      return [
        'Mostrar mi inventario',
        'Qué productos van a caducar',
        'Recomiéndame una receta',
        'Ver mi lista de compras',
      ];
    }
    
    final recentMessages = chatProvider.messages.reversed.take(3).toList();
    final suggestions = <String>{};
    
    for (final message in recentMessages) {
      if (message.sender == MessageSender.bot) {
        final lowerText = message.text.toLowerCase();
        
        if (lowerText.contains('receta')) {
          suggestions.addAll([
            'Ver ingredientes necesarios',
            'Añadir ingredientes a la lista',
            'Buscar recetas similares',
            'Guardar esta receta',
          ]);
        } else if (lowerText.contains('inventario')) {
          suggestions.addAll([
            'Productos que caducan pronto',
            'Añadir producto al inventario',
            'Buscar recetas con estos ingredientes',
            'Ver estadísticas del inventario',
          ]);
        } else if (lowerText.contains('lista de compras')) {
          suggestions.addAll([
            'Generar lista automática',
            'Marcar productos como comprados',
            'Ver productos favoritos',
            'Añadir más productos',
          ]);
        } else if (lowerText.contains('plan de comidas')) {
          suggestions.addAll([
            'Ver recetas del plan',
            'Añadir ingredientes a la lista',
            'Generar otro plan',
            'Modificar plan actual',
          ]);
        } else if (lowerText.contains('caducar') || lowerText.contains('expir')) {
          suggestions.addAll([
            'Generar recetas urgentes',
            'Plan de comidas prioritario',
            'Configurar alertas',
            'Ver inventario completo',
          ]);
        }
      }
    }
    
    // Si no hay sugerencias específicas, usar las generales
    if (suggestions.isEmpty) {
      suggestions.addAll([
        'Mostrar inventario',
        'Generar receta',
        'Lista de compras',
        'Plan de comidas',
      ]);
    }
    
    return suggestions.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
      appBar: _buildCustomAppBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
        child: SafeArea(
          child: Column(
            children: [
              // Cuerpo del chat (mensajes)
              Expanded(
                child: Consumer<AIChatProvider>(
                  builder: (context, chatProvider, child) {
                    if (!chatProvider.isInitialized) {
                      return _buildInitializingState();
                    }
                    
                    if (chatProvider.error != null) {
                      return _buildErrorState(chatProvider);
                    }
                    
                    final messages = chatProvider.messages;
                    
                    return Stack(
                      children: [
                        // Lista de mensajes o estado vacío
                        if (messages.isEmpty)
                          _buildEmptyChatState()
                        else
                          _buildMessagesList(messages, chatProvider),
                        
                        // Acciones rápidas con animación mejorada
                        if (_showQuickActions && (messages.isEmpty || !chatProvider.isLoading))
                          _buildAnimatedQuickActions(chatProvider),
                      ],
                    );
                  },
                ),
              ),
              
              // Indicador de actividad mejorado
              _buildActivityIndicator(),
              
              // Barra de entrada de mensajes mejorada
              _buildEnhancedMessageComposer(),
            ],
          ),
        ),
      ),
    );
  }
  
  PreferredSizeWidget _buildCustomAppBar() {
  return CustomAppBar(
    title: 'Asistente SmartPantry',
    // Remover esta línea que causa el error:
    // subtitle: 'Powered by IA',
    automaticallyImplyLeading: true,
    backgroundColor: AppTheme.coralMain,
    foregroundColor: Colors.white,
    actions: [
      // Botón para expandir/contraer acciones
      IconButton(
        icon: AnimatedRotation(
          turns: _showQuickActions ? 0.5 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Icon(_showQuickActions ? Icons.expand_less : Icons.expand_more),
        ),
        tooltip: _showQuickActions ? 'Ocultar acciones' : 'Mostrar acciones',
        onPressed: () {
          setState(() {
            _showQuickActions = !_showQuickActions;
          });
          if (_showQuickActions) {
            _slideAnimationController.forward();
          } else {
            _slideAnimationController.reverse();
          }
        },
      ),
      
      // Botón para limpiar conversación
      IconButton(
        icon: const Icon(Icons.delete_sweep_rounded),
        tooltip: 'Limpiar conversación',
        onPressed: () => _showResetConfirmDialog(),
      ),
      
      // Menú de opciones avanzado
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: _handleMenuSelection,
        itemBuilder: (context) => [
          _buildMenuItem('stats', Icons.analytics_outlined, 'Estadísticas del chat'),
          _buildMenuItem('export', Icons.download_rounded, 'Exportar conversación'),
          _buildMenuItem('voice_settings', Icons.mic_outlined, 'Configurar voz'),
          _buildMenuItem('help', Icons.help_outline, 'Ayuda del asistente'),
          const PopupMenuDivider(),
          _buildMenuItem('debug', Icons.bug_report_outlined, 'Información de debug'),
          _buildMenuItem('reinitialize', Icons.refresh, 'Reinicializar sistema'),
        ],
      ),
    ],
  );
}
  
  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
  
  void _handleMenuSelection(String value) {
    switch (value) {
      case 'stats':
        _showAdvancedChatStats();
        break;
      case 'export':
        _exportConversation();
        break;
      case 'voice_settings':
        _showVoiceSettings();
        break;
      case 'help':
        _showChatHelp();
        break;
      case 'debug':
        _showDebugInfo();
        break;
      case 'reinitialize':
        _reinitializeChat();
        break;
    }
  }
  
  Widget _buildInitializingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.coralMain.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralMain),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Inicializando asistente inteligente...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.coralMain,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configurando IA, cargando datos y preparando funciones avanzadas',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessagesList(List<ChatMessage> messages, AIChatProvider chatProvider) {
    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16.0),
          reverse: false,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isFirstOfType = index == 0 || 
                messages[index - 1].sender != message.sender;
            final isLastOfType = index == messages.length - 1 || 
                messages[index + 1].sender != message.sender;
            
            if (message.type == MessageType.suggestion) {
              return _buildEnhancedSuggestionBubble(message, index);
            } else {
              return _buildEnhancedMessageBubble(
                message, 
                isFirstOfType, 
                isLastOfType,
                index,
              );
            }
          },
        ),
        
        // Indicador de "escribiendo..." mejorado
        if (chatProvider.isLoading)
          _buildAdvancedTypingIndicator(),
      ],
    );
  }
  
  Widget _buildAdvancedTypingIndicator() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      bottom: 16,
      left: 64,
      child: AnimatedBuilder(
        animation: _typingAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.coralMain.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    size: 18,
                    color: AppTheme.coralMain,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Asistente está pensando...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildAdvancedDot(0),
                        const SizedBox(width: 4),
                        _buildAdvancedDot(1),
                        const SizedBox(width: 4),
                        _buildAdvancedDot(2),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildAdvancedDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimation,
      builder: (context, child) {
        final value = math.sin((_typingAnimation.value + index * 0.3) * 2 * math.pi);
        return Transform.translate(
          offset: Offset(0, value * 3),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.coralMain.withOpacity(0.7 + value * 0.3),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEnhancedMessageBubble(ChatMessage message, bool isFirst, bool isLast, int index) {
    final isUserMessage = message.sender == MessageSender.user;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(
            opacity: value,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!isUserMessage && isLast) _buildEnhancedAvatar(),
                  if (!isUserMessage && !isLast) const SizedBox(width: 40),
                  
                  Flexible(
                    child: GestureDetector(
                      onTap: () {
                        if (message.type == MessageType.action) {
                          _executeActionFromMessage(message);
                        }
                      },
                      onLongPress: () => _showMessageOptions(message),
                      child: Container(
                        margin: EdgeInsets.only(
                          left: isUserMessage ? 64.0 : 8.0,
                          right: isUserMessage ? 8.0 : 64.0,
                        ),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: isUserMessage 
                            ? AppTheme.coralMain 
                            : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.white),
                          borderRadius: _getBubbleBorderRadius(isUserMessage, isFirst, isLast),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Contenido del mensaje con markdown mejorado
                            MarkdownBody(
                              data: message.text,
                              styleSheet: _getMarkdownStyle(isUserMessage, isDarkMode),
                              selectable: true,
                            ),
                            
                            // Botones de acción si los hay
                            if (message.type == MessageType.action && message.metadata != null) 
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: _buildAdvancedActionButtons(message),
                              ),
                            
                            // Timestamp y estado del mensaje
                            const SizedBox(height: 8),
                            _buildMessageFooter(message, isUserMessage),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  if (isUserMessage && isLast) _buildUserAvatar(),
                  if (isUserMessage && !isLast) const SizedBox(width: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  BorderRadius _getBubbleBorderRadius(bool isUser, bool isFirst, bool isLast) {
    const radius = Radius.circular(20);
    const smallRadius = Radius.circular(6);
    
    if (isUser) {
      return BorderRadius.only(
        topLeft: radius,
        topRight: isFirst ? radius : smallRadius,
        bottomLeft: radius,
        bottomRight: isLast ? radius : smallRadius,
      );
    } else {
      return BorderRadius.only(
        topLeft: isFirst ? radius : smallRadius,
        topRight: radius,
        bottomLeft: isLast ? radius : smallRadius,
        bottomRight: radius,
      );
    }
  }
  
  MarkdownStyleSheet _getMarkdownStyle(bool isUserMessage, bool isDarkMode) {
    final baseColor = isUserMessage 
      ? Colors.white 
      : (isDarkMode ? Colors.white : Colors.black87);
    
    return MarkdownStyleSheet(
      p: TextStyle(
        color: baseColor,
        fontSize: 16,
        height: 1.4,
      ),
      strong: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      em: TextStyle(
        color: baseColor.withOpacity(0.9),
        fontStyle: FontStyle.italic,
        fontSize: 16,
      ),
      h1: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
      h2: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
      blockquote: TextStyle(
        color: baseColor.withOpacity(0.8),
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
      code: TextStyle(
        backgroundColor: Colors.grey.withOpacity(0.2),
        fontFamily: 'monospace',
        fontSize: 14,
      ),
    );
  }
  
  Widget _buildMessageFooter(ChatMessage message, bool isUserMessage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Indicadores de tipo de mensaje
        if (message.type == MessageType.action)
          Icon(
            Icons.touch_app_rounded,
            size: 12,
            color: isUserMessage 
              ? Colors.white.withOpacity(0.7) 
              : AppTheme.coralMain.withOpacity(0.7),
          ),
        
        const Spacer(),
        
        // Timestamp
        Text(
          _formatTimestamp(message.timestamp),
          style: TextStyle(
            color: isUserMessage 
              ? Colors.white.withOpacity(0.7) 
              : Colors.grey.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildAdvancedActionButtons(ChatMessage message) {
    final actionType = message.metadata!['actionType'] as String?;
    final actionData = message.metadata!['actionData'] as Map<String, dynamic>?;
    
    if (actionType == null) return const SizedBox.shrink();
    
    return _getActionButtonsForType(actionType, actionData);
  }
  
  Widget _getActionButtonsForType(String actionType, Map<String, dynamic>? actionData) {
    switch (actionType) {
      case 'multiple_recipe_recommendations':
        return _buildRecipeRecommendationActions(actionData);
      
      case 'meal_plan_preview_advanced':
        return _buildMealPlanPreviewActions(actionData);
      
      case 'shopping_suggestions':
        return _buildShoppingSuggestionsActions(actionData);
      
      case 'expiring_products_analysis':
        return _buildExpiringProductsActions(actionData);
      
      case 'duplicate_item_detected':
        return _buildDuplicateItemActions(actionData);
      
      case 'product_added_successfully':
        return _buildProductAddedActions(actionData);
      
      case 'meal_plan_saved_successfully':
        return _buildMealPlanSavedActions(actionData);
      
      case 'item_marked_purchased':
        return _buildItemPurchasedActions(actionData);
      
      case 'barcode_guidance':
      case 'ocr_guidance':
        return _buildScanGuidanceActions(actionType);
      
      case 'settings_overview':
        return _buildSettingsActions(actionData);
      
      case 'detailed_statistics':
        return _buildStatisticsActions(actionData);
      
      case 'favorites_overview':
        return _buildFavoritesActions(actionData);
      
      default:
        return _buildGenericActions();
    }
  }
  
  Widget _buildRecipeRecommendationActions(Map<String, dynamic>? data) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Ver detalles',
              icon: Icons.visibility_rounded,
              color: AppTheme.coralMain,
              onPressed: () => _useSuggestion('Ver detalles de la primera receta'),
            ),
            _buildActionButton(
              label: 'Guardar',
              icon: Icons.bookmark_add_rounded,
              color: AppTheme.successGreen,
              onPressed: () => _useSuggestion('Guardar la primera receta'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(
            label: 'Añadir ingredientes a lista de compras',
            icon: Icons.add_shopping_cart_rounded,
            color: AppTheme.softTeal,
            onPressed: () => _useSuggestion('Añadir ingredientes faltantes a mi lista'),
            isFullWidth: true,
          ),
        ),
      ],
    );
  }
  
  Widget _buildMealPlanPreviewActions(Map<String, dynamic>? data) {
    final daysGenerated = data?['daysGenerated'] ?? 0;
    final recipesCount = (data?['recipes'] as List?)?.length ?? 0;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.coralMain.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.coralMain, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plan generado: $daysGenerated días con $recipesCount recetas',
                  style: TextStyle(
                    color: AppTheme.coralMain,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Guardar plan',
              icon: Icons.save_rounded,
              color: AppTheme.successGreen,
              onPressed: () => _useSuggestion('Sí, guardar este plan'),
            ),
            _buildActionButton(
              label: 'Generar otro',
              icon: Icons.refresh_rounded,
              color: AppTheme.coralMain,
              onPressed: () => _useSuggestion('Generar plan diferente'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(
            label: 'Ver detalles de las recetas',
            icon: Icons.menu_book_rounded,
            color: AppTheme.softTeal,
            onPressed: () => _useSuggestion('Ver detalles de las recetas del plan'),
            isFullWidth: true,
          ),
        ),
      ],
    );
  }
  
  Widget _buildShoppingSuggestionsActions(Map<String, dynamic>? data) {
    final suggestions = data?['suggestions'] as List? ?? [];
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Añadir todas',
              icon: Icons.add_circle_outline,
              color: AppTheme.successGreen,
              onPressed: () => _useSuggestion('Añadir todas las sugerencias'),
            ),
            _buildActionButton(
              label: 'Seleccionar',
              icon: Icons.checklist_rounded,
              color: AppTheme.coralMain,
              onPressed: () => _useSuggestion('Déjame seleccionar cuáles añadir'),
            ),
          ],
        ),
        if (suggestions.length > 3) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              label: 'Añadir solo los primeros 3',
              icon: Icons.playlist_add_rounded,
              color: AppTheme.softTeal,
              onPressed: () => _useSuggestion('Añadir solo los primeros 3 productos'),
              isFullWidth: true,
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildExpiringProductsActions(Map<String, dynamic>? data) {
    final criticalCount = data?['criticalCount'] ?? 0;
    
    return Column(
      children: [
        if (criticalCount > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, color: AppTheme.errorRed, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡URGENTE! $criticalCount productos críticos',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Recetas urgentes',
              icon: Icons.restaurant_rounded,
              color: AppTheme.errorRed,
              onPressed: () => _useSuggestion('Generar recetas con productos que caducan'),
            ),
            _buildActionButton(
              label: 'Plan prioritario',
              icon: Icons.calendar_today_rounded,
              color: AppTheme.coralMain,
              onPressed: () => _useSuggestion('Crear plan de comidas prioritario'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Marcar consumidos',
              icon: Icons.check_circle_outline,
              color: AppTheme.successGreen,
              onPressed: () => _useSuggestion('Marcar productos como consumidos'),
            ),
            _buildActionButton(
              label: 'Config. alertas',
              icon: Icons.notifications_outlined,
              color: AppTheme.softTeal,
              onPressed: () => _useSuggestion('Configurar alertas de caducidad'),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildDuplicateItemActions(Map<String, dynamic>? data) {
    final existingItem = data?['existingItem'] as Map<String, dynamic>?;
    final itemName = existingItem?['name'] ?? 'producto';
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.yellowAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.content_copy_rounded, color: AppTheme.yellowAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ya tienes "$itemName" en tu lista',
                  style: TextStyle(
                    color: AppTheme.yellowAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Aumentar cantidad',
              icon: Icons.add_rounded,
              color: AppTheme.successGreen,
              onPressed: () => _useSuggestion('Aumentar cantidad del producto existente'),
            ),
            _buildActionButton(
              label: 'Añadir separado',
              icon: Icons.post_add_rounded,
              color: AppTheme.coralMain,
              onPressed: () => _useSuggestion('Añadir como producto separado'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Reemplazar',
              icon: Icons.swap_horiz_rounded,
              color: AppTheme.softTeal,
              onPressed: () => _useSuggestion('Reemplazar con la nueva información'),
            ),
            _buildActionButton(
              label: 'Cancelar',
              icon: Icons.cancel_outlined,
              color: AppTheme.mediumGrey,
              onPressed: () => _useSuggestion('Cancelar operación'),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildProductAddedActions(Map<String, dynamic>? data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          label: 'Ver inventario',
          icon: Icons.inventory_2_rounded,
          color: AppTheme.softTeal,
          onPressed: () => Navigator.pushNamed(context, Routes.inventory),
        ),
        _buildActionButton(
          label: 'Añadir más',
          icon: Icons.add_circle_outline,
          color: AppTheme.coralMain,
          onPressed: () => _useSuggestion('Añadir otro producto al inventario'),
        ),
      ],
    );
  }
  
  Widget _buildMealPlanSavedActions(Map<String, dynamic>? data) {
    final daysCount = data?['daysCount'] ?? 0;
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.successGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plan de $daysCount días guardado exitosamente',
                  style: TextStyle(
                    color: AppTheme.successGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Ver calendario',
              icon: Icons.calendar_view_month_rounded,
              color: AppTheme.coralMain,
              onPressed: () => Navigator.pushNamed(context, Routes.mealPlanner),
            ),
            _buildActionButton(
              label: 'Ver recetas',
              icon: Icons.menu_book_rounded,
              color: AppTheme.softTeal,
              onPressed: () => Navigator.pushNamed(context, Routes.recipes),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildItemPurchasedActions(Map<String, dynamic>? data) {
    final itemName = data?['itemName'] ?? 'producto';
    final completionRate = data?['completionRate'] ?? 0;
    
    return Column(
      children: [
        if (completionRate >= 100) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.celebration_rounded, color: AppTheme.successGreen, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '¡Lista de compras completada! 🎉',
                    style: TextStyle(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Ver lista completa',
              icon: Icons.shopping_cart_rounded,
              color: AppTheme.softTeal,
              onPressed: () => Navigator.pushNamed(context, Routes.shoppingList),
            ),
            _buildActionButton(
              label: 'Mover al inventario',
              icon: Icons.move_to_inbox_rounded,
              color: AppTheme.coralMain,
              onPressed: () => _useSuggestion('Mover $itemName al inventario'),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildScanGuidanceActions(String actionType) {
    final isBarcode = actionType == 'barcode_guidance';
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(
            label: isBarcode ? 'Abrir escáner de códigos' : 'Activar reconocimiento OCR',
            icon: isBarcode ? Icons.qr_code_scanner_rounded : Icons.camera_alt_rounded,
            color: AppTheme.coralMain,
            onPressed: () {
              if (isBarcode) {
                // Navigator.pushNamed(context, Routes.barcodeScanner);
                _showFeatureComingSoon('Escáner de códigos de barras');
              } else {
                // Navigator.pushNamed(context, Routes.ocrScanner);
                _showFeatureComingSoon('Reconocimiento OCR');
              }
            },
            isFullWidth: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Añadir manualmente',
              icon: Icons.edit_rounded,
              color: AppTheme.softTeal,
              onPressed: () => Navigator.pushNamed(context, Routes.addProduct),
            ),
            _buildActionButton(
              label: 'Ver inventario',
              icon: Icons.inventory_2_rounded,
              color: AppTheme.mediumGrey,
              onPressed: () => Navigator.pushNamed(context, Routes.inventory),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildSettingsActions(Map<String, dynamic>? data) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionChip('Alertas de caducidad', Icons.notifications_outlined, 
            () => _useSuggestion('Cambiar alertas de caducidad')),
        _buildActionChip('Preferencias de cocina', Icons.restaurant_outlined, 
            () => _useSuggestion('Actualizar preferencias de cocina')),
        _buildActionChip('Configurar notificaciones', Icons.settings_outlined, 
            () => _useSuggestion('Configurar notificaciones')),
        _buildActionChip('Personalizar IA', Icons.smart_toy_outlined, 
            () => _useSuggestion('Personalizar asistente IA')),
      ],
    );
  }
  
  Widget _buildStatisticsActions(Map<String, dynamic>? data) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              label: 'Ver inventario',
              icon: Icons.inventory_2_rounded,
              color: AppTheme.softTeal,
              onPressed: () => Navigator.pushNamed(context, Routes.inventory),
            ),
            _buildActionButton(
              label: 'Ver recetas',
              icon: Icons.restaurant_rounded,
              color: AppTheme.coralMain,
              onPressed: () => Navigator.pushNamed(context, Routes.recipes),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(
            label: 'Generar reporte detallado',
            icon: Icons.assessment_rounded,
            color: AppTheme.yellowAccent,
            onPressed: () => _useSuggestion('Generar reporte detallado de estadísticas'),
            isFullWidth: true,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFavoritesActions(Map<String, dynamic>? data) {
    final hasProducts = (data?['favoriteProductsCount'] ?? 0) > 0;
    final hasRecipes = (data?['favoriteRecipesCount'] ?? 0) > 0;
    
    return Column(
      children: [
        if (hasProducts && hasRecipes) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                label: 'Recetas con favoritos',
                icon: Icons.favorite_rounded,
                color: AppTheme.coralMain,
                onPressed: () => _useSuggestion('Recetas con mis productos favoritos'),
              ),
              _buildActionButton(
                label: 'Lista automática',
                icon: Icons.auto_awesome_rounded,
                color: AppTheme.successGreen,
                onPressed: () => _useSuggestion('Crear lista con productos favoritos'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: _buildActionButton(
            label: hasProducts || hasRecipes 
                ? 'Plan con favoritos' 
                : 'Aprender a añadir favoritos',
            icon: hasProducts || hasRecipes 
                ? Icons.calendar_today_rounded 
                : Icons.help_outline_rounded,
            color: AppTheme.softTeal,
            onPressed: () => _useSuggestion(
              hasProducts || hasRecipes 
                  ? 'Generar plan priorizando favoritos'
                  : 'Cómo añadir favoritos'
            ),
            isFullWidth: true,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGenericActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          label: 'Ayuda',
          icon: Icons.help_outline_rounded,
          color: AppTheme.mediumGrey,
          onPressed: () => _useSuggestion('Ayuda'),
        ),
        _buildActionButton(
          label: 'Inventario',
          icon: Icons.inventory_2_rounded,
          color: AppTheme.softTeal,
          onPressed: () => _useSuggestion('Mostrar mi inventario'),
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required String label, 
    required IconData icon, 
    required Color color,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isFullWidth ? 20 : 16, 
          vertical: 12,
        ),
        textStyle: TextStyle(
          fontSize: isFullWidth ? 14 : 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        shadowColor: color.withOpacity(0.3),
      ),
    );
  }
  
  Widget _buildActionChip(String label, IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.coralMain.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.coralMain.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.coralMain),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.coralMain,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEnhancedSuggestionBubble(ChatMessage suggestion, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 200 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => _useSuggestion(suggestion.text),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    margin: const EdgeInsets.only(left: 56.0, right: 80.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.coralMain.withOpacity(0.1),
                          AppTheme.coralMain.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: AppTheme.coralMain.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.coralMain.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.coralMain.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: AppTheme.coralMain,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            suggestion.text,
                            style: TextStyle(
                              color: AppTheme.coralMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEnhancedAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.coralMain, AppTheme.coralMain.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.coralMain.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.smart_toy_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
  
  Widget _buildUserAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.softTeal, AppTheme.softTeal.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.softTeal.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
  
  Widget _buildAnimatedQuickActions(AIChatProvider chatProvider) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                Theme.of(context).scaffoldBackgroundColor,
              ],
              stops: const [0.0, 0.1, 1.0],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildQuickActions(),
              _buildSmartSuggestions(chatProvider),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF1E1E1E) 
          : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.coralMain.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  color: AppTheme.coralMain,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Acciones rápidas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.coralMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Primera fila - Inventario y Caducidad
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Mi Inventario',
                  subtitle: 'Ver todos los productos',
                  color: AppTheme.softTeal,
                  onTap: () => _handleQuickAction('Mostrar mi inventario completo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.access_time_rounded,
                  title: 'Próximos a vencer',
                  subtitle: 'Productos que caducan',
                  color: AppTheme.errorRed,
                  onTap: () => _handleQuickAction('Qué productos van a caducar esta semana'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Segunda fila - Recetas IA y Lista de compras
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Recetas con IA',
                  subtitle: 'Recomendaciones inteligentes',
                  color: AppTheme.coralMain,
                  onTap: () => _handleQuickAction('Recomiéndame recetas personalizadas con IA'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Lista de Compras',
                  subtitle: 'Gestionar compras',
                  color: AppTheme.yellowAccent,
                  onTap: () => _handleQuickAction('Mostrar mi lista de compras actual'),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Tercera fila - Plan semanal y Estadísticas
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.calendar_view_week_rounded,
                  title: 'Plan Semanal',
                  subtitle: 'Generar con IA avanzada',
                  color: AppTheme.successGreen,
                  onTap: () => _handleQuickAction('Genera un plan de comidas inteligente para toda la semana'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.analytics_outlined,
                  title: 'Estadísticas',
                  subtitle: 'Reportes y análisis',
                  color: AppTheme.mediumGrey,
                  onTap: () => _handleQuickAction('Mostrar estadísticas completas de mi cocina'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSmartSuggestions(AIChatProvider chatProvider) {
    final suggestions = _generateSmartSuggestions(chatProvider);
    
    if (suggestions.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF1A1A1A) 
          : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.coralMain.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.coralMain.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: AppTheme.coralMain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sugerencias inteligentes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.coralMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.asMap().entries.map((entry) {
              final index = entry.key;
              final suggestion = entry.value;
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 100)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: _buildSuggestionChip(suggestion, () => _handleQuickAction(suggestion)),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuggestionChip(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.coralMain.withOpacity(0.1),
              AppTheme.coralMain.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: AppTheme.coralMain.withOpacity(0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: AppTheme.coralMain,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: AppTheme.coralMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityIndicator() {
    return Consumer<AIChatProvider>(
      builder: (context, chatProvider, child) {
        if (!chatProvider.isLoading) {
          return const SizedBox(height: 2);
        }
        
        return SizedBox(
          height: 3,
          child: LinearProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralMain),
            backgroundColor: AppTheme.coralMain.withOpacity(0.2),
          ),
        );
      },
    );
  }
  
  Widget _buildEnhancedMessageComposer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Botón de funciones adicionales
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2A2A) : AppTheme.lightGrey,
                shape: BoxShape.circle,
              ),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppTheme.coralMain,
                  size: 28,
                ),
                onSelected: _handleComposerAction,
                itemBuilder: (context) => [
                  _buildComposerMenuItem('voice', Icons.mic_rounded, 'Mensaje de voz'),
                  _buildComposerMenuItem('scan', Icons.qr_code_scanner_rounded, 'Escanear código'),
                  _buildComposerMenuItem('photo', Icons.camera_alt_rounded, 'Tomar foto'),
                  _buildComposerMenuItem('templates', Icons.text_snippet_rounded, 'Plantillas'),
                ],
              ),
            ),
            
            // Campo de texto expandido
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2A2A2A) : AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(25.0),
                  border: Border.all(
                    color: _isComposing 
                      ? AppTheme.coralMain.withOpacity(0.5)
                      : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Pregúntame sobre inventario, recetas, planes de comida...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      size: 22,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _isComposing ? _handleSubmitted : null,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Botón de envío animado
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isComposing ? _pulseAnimation.value : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _isComposing
                        ? LinearGradient(
                            colors: [AppTheme.coralMain, AppTheme.coralMain.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                      color: _isComposing ? null : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: _isComposing ? [
                        BoxShadow(
                          color: AppTheme.coralMain.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isComposing ? Icons.send_rounded : Icons.send_outlined,
                          key: ValueKey(_isComposing),
                          size: _isComposing ? 22 : 20,
                        ),
                      ),
                      color: Colors.white,
                      onPressed: _isComposing 
                        ? () => _handleSubmitted(_messageController.text) 
                        : null,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  PopupMenuItem<String> _buildComposerMenuItem(String value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.coralMain),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
  
  void _handleComposerAction(String action) {
    switch (action) {
      case 'voice':
        _handleVoiceInput();
        break;
      case 'scan':
        _showFeatureComingSoon('Escáner de códigos');
        break;
      case 'photo':
        _showFeatureComingSoon('Reconocimiento por foto');
        break;
      case 'templates':
        _showMessageTemplates();
        break;
    }
  }
  
  Widget _buildErrorState(AIChatProvider chatProvider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: AppTheme.errorRed,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Error en el asistente',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              chatProvider.error ?? 'Error desconocido',
              style: TextStyle(color: AppTheme.errorRed.withOpacity(0.8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    chatProvider.clearError();
                    _reinitializeChat();
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Reportar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: BorderSide(color: AppTheme.errorRed),
                  ),
                  onPressed: () => _showDebugInfo(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyChatState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // Avatar principal con animación
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.coralMain,
                        AppTheme.coralMain.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.coralMain.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Título principal
          Text(
            '¡Hola! Soy tu asistente\nSmartPantry con IA',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.coralMain,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Descripción
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.lightGrey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Puedo ayudarte con tu inventario, generar recetas personalizadas con IA, crear planes de comida inteligentes y gestionar tu lista de compras. Todo con tecnología avanzada de procesamiento natural.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Características principales
          _buildFeatureHighlights(),
          
          const SizedBox(height: 32),
          
          // Ejemplos de consultas
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.coralMain.withOpacity(0.05),
                  AppTheme.coralMain.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.coralMain.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppTheme.coralMain,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ejemplos de lo que puedes preguntar:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.coralMain,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...examples.asMap().entries.map((entry) {
                  final index = entry.key;
                  final example = entry.value;
                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 500 + (index * 200)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset((1 - value) * 50, 0),
                        child: Opacity(
                          opacity: value,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppTheme.coralMain,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    example,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  static const List<String> examples = [
    '"¿Qué productos tengo en la nevera?"',
    '"Recomiéndame una receta vegetariana con IA"',
    '"Añade 2 litros de leche a mi lista de compras"',
    '"Genera un plan de comidas inteligente para la semana"',
    '"Qué productos van a caducar en los próximos días"',
    '"Crea recetas con productos que caducan pronto"',
    '"Mostrar estadísticas de mi inventario"',
  ];
  
  Widget _buildFeatureHighlights() {
    final features = [
      {
        'icon': Icons.psychology_rounded,
        'title': 'IA Avanzada',
        'subtitle': 'Procesamiento natural',
        'color': AppTheme.coralMain,
      },
      {
        'icon': Icons.inventory_2_rounded,
        'title': 'Gestión Inteligente',
        'subtitle': 'Inventario automático',
        'color': AppTheme.softTeal,
      },
      {
        'icon': Icons.restaurant_rounded,
        'title': 'Recetas Personalizadas',
        'subtitle': 'Con tus ingredientes',
        'color': AppTheme.yellowAccent,
      },
      {
        'icon': Icons.calendar_today_rounded,
        'title': 'Planificación Smart',
        'subtitle': 'Menús optimizados',
        'color': AppTheme.successGreen,
      },
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 600 + (index * 150)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (feature['color'] as Color).withOpacity(0.1),
                      (feature['color'] as Color).withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (feature['color'] as Color).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (feature['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        color: feature['color'] as Color,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      feature['title'] as String,
                      style: TextStyle(
                        color: feature['color'] as Color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature['subtitle'] as String,
                      style: TextStyle(
                        color: (feature['color'] as Color).withOpacity(0.8),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // ========== MÉTODOS DE UTILIDAD Y FUNCIONES AUXILIARES ==========
  
  void _showMessageOptions(ChatMessage message) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copiar mensaje'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                _showSnackBar('Mensaje copiado');
              },
            ),
            if (message.sender == MessageSender.bot) ...[
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Regenerar respuesta'),
                onTap: () {
                  Navigator.pop(context);
                  _useSuggestion('Explícame eso de otra manera');
                },
              ),
              ListTile(
                leading: const Icon(Icons.thumb_up_outlined),
                title: const Text('Respuesta útil'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('Gracias por tu feedback');
                },
              ),
              ListTile(
                leading: const Icon(Icons.thumb_down_outlined),
                title: const Text('Mejorar respuesta'),
                onTap: () {
                  Navigator.pop(context);
                  _showSnackBar('Feedback registrado, trabajamos para mejorar');
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  void _handleVoiceInput() {
    _showFeatureComingSoon('Entrada por voz');
  }
  
  void _showFeatureComingSoon(String feature) {
    _showSnackBar('$feature disponible próximamente', icon: Icons.account_circle_outlined);
  }
  
  void _showSnackBar(String message, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.coralMain,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  void _showMessageTemplates() {
    final templates = [
      'Mostrar mi inventario completo',
      'Qué productos caducan esta semana',
      'Recomiéndame una receta vegetariana',
      'Generar plan de comidas para 3 días',
      'Añadir 2 litros de leche a la lista',
      'Mostrar estadísticas del inventario',
      'Crear recetas con productos que caducan',
      'Configurar alertas de caducidad',
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Plantillas de mensajes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.coralMain.withOpacity(0.1),
                      child: Icon(
                        Icons.text_snippet_rounded,
                        color: AppTheme.coralMain,
                        size: 20,
                      ),
                    ),
                    title: Text(template),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      _messageController.text = template;
                      setState(() {
                        _isComposing = true;
                      });
                      _focusNode.requestFocus();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  void _showAdvancedChatStats() {
    final provider = Provider.of<AIChatProvider>(context, listen: false);
    final debugInfo = provider.getDebugInfo() as Map<String, dynamic>;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estadísticas Avanzadas del Chat'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatCard('Estado General', [
                _buildStatRow('Total de mensajes', '${debugInfo['messagesCount'] ?? 0}'),
                _buildStatRow('Inicializado', (debugInfo['isInitialized'] as bool? ?? false) ? 'Sí' : 'No'),
                _buildStatRow('Cargando', (debugInfo['isLoading'] as bool? ?? false) ? 'Sí' : 'No'),
                _buildStatRow('Pensando', (debugInfo['isThinking'] as bool? ?? false) ? 'Sí' : 'No'),
              ]),
              const SizedBox(height: 16),
              _buildStatCard('Errores', [
                _buildStatRow('Tiene errores', (debugInfo['hasError'] as bool? ?? false) ? 'Sí' : 'No'),
                if (debugInfo['hasError'] as bool? ?? false)
                  _buildStatRow('Último error', (debugInfo['error'] as String?) ?? 'Desconocido'),
              ]),
              const SizedBox(height: 16),
              _buildStatCard('Último Mensaje', [
                if (debugInfo['lastMessage'] != null) ...[
                  _buildStatRow('Tipo', ((debugInfo['lastMessage'] as Map<String, dynamic>?)?['type'] as String?) ?? 'texto'),
                  _buildStatRow('Remitente', ((debugInfo['lastMessage'] as Map<String, dynamic>?)?['sender'] as String?) ?? 'desconocido'),
                  _buildStatRow('Hora', _formatTimestamp(DateTime.parse(((debugInfo['lastMessage'] as Map<String, dynamic>?)?['timestamp'] as String?) ?? DateTime.now().toIso8601String()))),
                ] else
                  const Text('No hay mensajes'),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportStats(debugInfo);
            },
            child: const Text('Exportar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.coralMain.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.coralMain,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
  
  void _exportStats(Map<String, dynamic> stats) {
    final statsText = _formatStatsForExport(stats);
    Clipboard.setData(ClipboardData(text: statsText));
    _showSnackBar('Estadísticas copiadas al portapapeles');
  }
  
  String _formatStatsForExport(Map<String, dynamic> stats) {
    final buffer = StringBuffer();
    buffer.writeln('=== ESTADÍSTICAS DEL CHAT SMARTPANTRY ===');
    buffer.writeln('Fecha: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('ESTADO GENERAL:');
    buffer.writeln('- Total mensajes: ${stats['messagesCount']}');
    buffer.writeln('- Inicializado: ${stats['isInitialized']}');
    buffer.writeln('- Cargando: ${stats['isLoading']}');
    buffer.writeln('- Pensando: ${stats['isThinking']}');
    buffer.writeln('');
    buffer.writeln('ERRORES:');
    buffer.writeln('- Tiene errores: ${stats['hasError']}');
    if (stats['hasError']) {
      buffer.writeln('- Error: ${stats['error']}');
    }
    buffer.writeln('');
    buffer.writeln('ÚLTIMO MENSAJE:');
    if (stats['lastMessage'] != null) {
      buffer.writeln('- Tipo: ${stats['lastMessage']['type']}');
      buffer.writeln('- Remitente: ${stats['lastMessage']['sender']}');
      buffer.writeln('- Hora: ${stats['lastMessage']['timestamp']}');
    } else {
      buffer.writeln('- No hay mensajes');
    }
    
    return buffer.toString();
  }
  
  void _exportConversation() {
    final chatProvider = Provider.of<AIChatProvider>(context, listen: false);
    final messages = chatProvider.messages;
    
    if (messages.isEmpty) {
      _showSnackBar('No hay mensajes para exportar');
      return;
    }
    
    final conversationText = _formatConversationForExport(messages);
    Clipboard.setData(ClipboardData(text: conversationText));
    _showSnackBar('Conversación copiada al portapapeles');
  }
  
  String _formatConversationForExport(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    buffer.writeln('=== CONVERSACIÓN SMARTPANTRY ===');
    buffer.writeln('Exportada: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total mensajes: ${messages.length}');
    buffer.writeln('');
    
    for (final message in messages) {
      final sender = message.sender == MessageSender.user ? 'USUARIO' : 'ASISTENTE';
      final timestamp = _formatTimestamp(message.timestamp);
      
      buffer.writeln('[$timestamp] $sender:');
      buffer.writeln(message.text);
      
      if (message.type == MessageType.action) {
        buffer.writeln('(Mensaje con acciones interactivas)');
      } else if (message.type == MessageType.suggestion) {
        buffer.writeln('(Sugerencia)');
      }
      
      buffer.writeln('');
    }
    
    return buffer.toString();
  }
  
  void _showVoiceSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mic_rounded, color: AppTheme.coralMain),
            const SizedBox(width: 8),
            const Text('Configuración de Voz'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.record_voice_over_rounded),
              title: const Text('Activar entrada de voz'),
              subtitle: const Text('Habla directamente al asistente'),
              trailing: Switch(
                value: false,
                onChanged: null, // Deshabilitado por ahora
                activeColor: AppTheme.coralMain,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.speaker_rounded),
              title: const Text('Respuestas por voz'),
              subtitle: const Text('El asistente te hablará'),
              trailing: Switch(
                value: false,
                onChanged: null, // Deshabilitado por ahora
                activeColor: AppTheme.coralMain,
              ),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Funciones de voz próximamente'),
              subtitle: Text('Estamos trabajando en integrar capacidades avanzadas de voz con IA.'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  
  void _showChatHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppTheme.coralMain),
            const SizedBox(width: 8),
            const Text('Ayuda del Asistente'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                '🤖 Capacidades del Asistente',
                [
                  'Generar recetas personalizadas con IA',
                  'Gestionar inventario inteligentemente',
                  'Crear planes de comidas optimizados',
                  'Administrar lista de compras',
                  'Alertas de productos que caducan',
                  'Análisis y estadísticas detalladas',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                '💬 Consejos de Uso',
                [
                  'Habla de forma natural - el asistente entiende contexto',
                  'Sé específico en tus consultas para mejores resultados',
                  'Usa las acciones rápidas para funcionalidades comunes',
                  'El asistente recuerda tu conversación anterior',
                  'Puedes hacer múltiples preguntas en un solo mensaje',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                '🚀 Funciones Avanzadas',
                [
                  'Reconocimiento de lenguaje natural avanzado',
                  'Generación de contenido contextual',
                  'Integración con todos los módulos de la app',
                  'Aprendizaje de tus preferencias de cocina',
                  'Sugerencias proactivas e inteligentes',
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _useSuggestion('Mostrar ejemplos de uso avanzado');
            },
            child: const Text('Ver ejemplos'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHelpSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.coralMain,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 8, right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.coralMain,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  void _showDebugInfo() {
    final chatProvider = Provider.of<AIChatProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bug_report_outlined, color: AppTheme.coralMain),
            const SizedBox(width: 8),
            const Text('Información de Debug'),
          ],
        ),
        content: SingleChildScrollView(
          child: _buildDebugInfo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sendDebugReport();
            },
            child: const Text('Enviar reporte'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDebugInfo() {
    return Consumer<AIChatProvider>(
      builder: (context, chatProvider, child) {
        final debugInfo = chatProvider.getDebugInfo() as Map<String, dynamic>;
        
        return ExpansionTile(
          title: const Text('🔧 Información de Debug'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estado del Chat:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildStatRow('Inicializado', (debugInfo['isInitialized'] as bool? ?? false) ? 'Sí' : 'No'),
                  _buildStatRow('Cargando', (debugInfo['isLoading'] as bool? ?? false) ? 'Sí' : 'No'),
                  _buildStatRow('Pensando', (debugInfo['isThinking'] as bool? ?? false) ? 'Sí' : 'No'),
                  _buildStatRow('Mensajes', '${debugInfo['messageCount'] ?? 0}'),
                  const Divider(),
                  _buildStatRow('Tiene errores', (debugInfo['hasError'] as bool? ?? false) ? 'Sí' : 'No'),
                  if (debugInfo['hasError'] as bool? ?? false)
                    _buildStatRow('Último error', (debugInfo['error'] as String?) ?? 'Desconocido'),
                  const Divider(),
                  if (debugInfo['lastMessage'] != null) ...[                    
                    const Text('Último mensaje:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    _buildStatRow('Tipo', ((debugInfo['lastMessage'] as Map<String, dynamic>?)?['type'] as String?) ?? 'texto'),
                    _buildStatRow('Remitente', ((debugInfo['lastMessage'] as Map<String, dynamic>?)?['sender'] as String?) ?? 'desconocido'),
                    _buildStatRow('Hora', _formatTimestamp(DateTime.parse(((debugInfo['lastMessage'] as Map<String, dynamic>?)?['timestamp'] as String?) ?? DateTime.now().toIso8601String()))),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  

  
  void _sendDebugReport() {
    _showSnackBar('Reporte de debug enviado (función simulada)');
  }
  
  void _reinitializeChat() {
    final chatProvider = Provider.of<AIChatProvider>(context, listen: false);
    chatProvider.clearMessages();
    
    setState(() {
      _showQuickActions = true;
    });
    
    _showSnackBar('Sistema reinicializado correctamente', icon: Icons.refresh_rounded);
  }
  
  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limpiar Conversación'),
          content: const Text(
            '¿Estás seguro de que quieres borrar todos los mensajes? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Limpiar',
                style: TextStyle(color: AppTheme.errorRed),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _clearConversation();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _clearConversation() {
    final chatProvider = Provider.of<AIChatProvider>(context, listen: false);
    chatProvider.clearMessages();
    
    setState(() {
      _showQuickActions = true;
    });
    
    _showSnackBar('Conversación limpiada', icon: Icons.cleaning_services_rounded);
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'ahora';
    }
  }
  
  Future<void> _showActionConfirmationDialog(Map<String, dynamic> actionData) async {
    final actionId = actionData['actionId'] as String;
    final preview = actionData['preview'] as Map<String, dynamic>;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤖 Confirmar Acción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('**Acción:** ${preview['action']}'),
            const SizedBox(height: 8),
            Text('**Producto:** ${preview['product']}'),
            if (preview['quantity'] != null)
              Text('**Cantidad:** ${preview['quantity']}'),
            if (preview['location'] != null)
              Text('**Ubicación:** ${preview['location']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    
    if (confirmed != null) {
      final chatProvider = Provider.of<AIChatProvider>(context, listen: false);
      await chatProvider.sendMessage('${confirmed ? "Sí, confirmo" : "No, cancelar"}');
    }
  }
}