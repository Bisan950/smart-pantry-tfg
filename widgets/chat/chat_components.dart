// lib/widgets/chat/chat_components.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:math' as math;
import '../../config/theme.dart';
import '../../models/chat_message_model.dart';
import '../../config/routes.dart';

/// Widget para renderizar una burbuja de mensaje
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String)? onSuggestionTap;
  final Function(ChatMessage)? onActionExecute;
  
  const ChatBubble({
    super.key,
    required this.message,
    this.onSuggestionTap,
    this.onActionExecute,
  });

  @override
  Widget build(BuildContext context) {
    final isUserMessage = message.sender == MessageSender.user;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (message.type == MessageType.suggestion) {
      return _buildSuggestion(context);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Avatar del bot (solo para mensajes del bot)
          if (!isUserMessage) _buildBotAvatar(),
          
          // Contenido del mensaje
          Flexible(
            child: GestureDetector(
              onTap: () {
                // Ejecutar acción al tocar si es un mensaje con acción
                if (message.type == MessageType.action && onActionExecute != null) {
                  onActionExecute!(message);
                }
              },
              child: Container(
                margin: EdgeInsets.only(
                  left: isUserMessage ? 32.0 : 8.0,
                  right: isUserMessage ? 8.0 : 32.0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isUserMessage 
                    ? AppTheme.coralMain 
                    : (isDarkMode ? const Color(0xFF2C2C2C) : AppTheme.lightGrey),
                  borderRadius: BorderRadius.circular(20),
                  // Añadir un ligero sombreado
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contenido del mensaje con soporte para markdown
                    MarkdownBody(
                      data: message.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isUserMessage 
                            ? Colors.white 
                            : (isDarkMode ? Colors.white : Colors.black87),
                          fontSize: 16,
                        ),
                        strong: TextStyle(
                          color: isUserMessage 
                            ? Colors.white 
                            : (isDarkMode ? Colors.white : Colors.black87),
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: isUserMessage 
                            ? Colors.white.withOpacity(0.9) 
                            : (isDarkMode ? Colors.white.withOpacity(0.9) : Colors.black54),
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: TextStyle(
                          color: isUserMessage 
                            ? Colors.white 
                            : (isDarkMode ? Colors.white : Colors.black87),
                        ),
                      ),
                      selectable: true, // Hacer seleccionable el texto
                    ),
                    
                    // Mostrar botones de acción si es un mensaje de acción
                    if (message.type == MessageType.action && message.metadata != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: _buildActionButtons(context, message),
                      ),
                    
                    // Hora del mensaje
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        _formatTimeStamp(message.timestamp),
                        style: TextStyle(
                          color: isUserMessage 
                            ? Colors.white.withOpacity(0.7) 
                            : Colors.grey.withOpacity(0.8),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Avatar del usuario (solo para mensajes del usuario)
          if (isUserMessage) _buildUserAvatar(),
        ],
      ),
    );
  }
  
  // Widget para construir una sugerencia seleccionable
  Widget _buildSuggestion(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () {
            if (onSuggestionTap != null) {
              onSuggestionTap!(message.text);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            margin: const EdgeInsets.only(left: 48.0, right: 64.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: isDarkMode 
                ? AppTheme.coralMain.withOpacity(0.15) 
                : AppTheme.coralMain.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.coralMain.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: AppTheme.coralMain,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: AppTheme.coralMain,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Widget para botones de acción dentro de un mensaje
  Widget _buildActionButtons(BuildContext context, ChatMessage message) {
    final actionType = message.metadata!['actionType'] as String?;
    final actionData = message.metadata!['actionData'] as Map<String, dynamic>?;
    
    if (actionType == null) return const SizedBox.shrink();
    
    // Botones según el tipo de acción
    switch (actionType) {
      case 'recipe_recommendation':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              context: context,
              label: 'Ver receta',
              icon: Icons.visibility_rounded,
              onPressed: () {
                // Navegar a la receta
                final recipeId = actionData?['recipeId'] as String?;
                if (recipeId != null) {
                  Navigator.pushNamed(
                    context, 
                    Routes.recipeDetail,
                    arguments: {'recipeId': recipeId},
                  );
                }
              },
            ),
            _buildActionButton(
              context: context,
              label: 'Guardar',
              icon: Icons.save_rounded,
              onPressed: () {
                if (onActionExecute != null) {
                  onActionExecute!(message);
                }
              },
            ),
          ],
        );
        
      case 'meal_plan_generated':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              context: context,
              label: 'Guardar plan',
              icon: Icons.calendar_today_rounded,
              onPressed: () {
                if (onActionExecute != null) {
                  onActionExecute!(message);
                }
              },
            ),
            _buildActionButton(
              context: context,
              label: 'Añadir ingredientes',
              icon: Icons.add_shopping_cart_rounded,
              onPressed: () {
                if (onActionExecute != null) {
                  onActionExecute!(message);
                }
              },
            ),
          ],
        );
        
      case 'add_to_shopping_list':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionButton(
              context: context,
              label: 'Ver lista de compras',
              icon: Icons.shopping_cart_rounded,
              onPressed: () {
                Navigator.pushNamed(context, Routes.shoppingList);
              },
            ),
          ],
        );
      
      default:
        return const SizedBox.shrink();
    }
  }
  
  // Widget para un botón de acción
  Widget _buildActionButton({
    required BuildContext context,
    required String label, 
    required IconData icon, 
    required VoidCallback onPressed
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.coralMain,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  // Widget para el avatar del bot
  Widget _buildBotAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.coralMain,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.smart_toy_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
  
  // Widget para el avatar del usuario
  Widget _buildUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: AppTheme.softTeal,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
  
  // Formatea la hora del mensaje
  String _formatTimeStamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    
    if (messageDate == today) {
      // Si es hoy, mostrar solo la hora
      return '$hour:$minute';
    } else {
      // Si es otro día, incluir la fecha
      final day = timestamp.day.toString().padLeft(2, '0');
      final month = timestamp.month.toString().padLeft(2, '0');
      return '$day/$month $hour:$minute';
    }
  }
}

/// Widget para el campo de entrada de mensajes
class ChatInputField extends StatefulWidget {
  final Function(String) onSubmit;
  final String hintText;
  final bool disabled;
  final VoidCallback? onVoiceInput;
  
  const ChatInputField({
    super.key,
    required this.onSubmit,
    this.hintText = 'Pregúntame cualquier cosa...',
    this.disabled = false,
    this.onVoiceInput,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }
  
  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  void _onTextChanged() {
    setState(() {
      _isComposing = _controller.text.trim().isNotEmpty;
    });
  }
  
  void _handleSubmitted(String text) {
    if (widget.disabled) return;
    
    widget.onSubmit(text);
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Campo de entrada de texto
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2C2C2C) : AppTheme.lightGrey,
                  borderRadius: BorderRadius.circular(24.0),
                  border: widget.disabled 
                    ? Border.all(color: Colors.grey.withOpacity(0.3)) 
                    : null,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: widget.disabled 
                      ? 'Chat no disponible en este momento' 
                      : widget.hintText,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    // Icono de micrófono
                    prefixIcon: widget.onVoiceInput != null ? IconButton(
                      icon: Icon(
                        Icons.mic_none_rounded,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      onPressed: widget.disabled ? null : widget.onVoiceInput,
                    ) : null,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  enabled: !widget.disabled,
                  maxLines: null, // Permitir múltiples líneas
                  textInputAction: TextInputAction.send,
                  onSubmitted: _isComposing && !widget.disabled ? _handleSubmitted : null,
                ),
              ),
            ),
            
            // Botón de enviar
            Container(
              decoration: BoxDecoration(
                color: _isComposing && !widget.disabled 
                  ? AppTheme.coralMain 
                  : Colors.grey.withOpacity(widget.disabled ? 0.3 : 0.7),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded),
                color: Colors.white,
                onPressed: _isComposing && !widget.disabled 
                  ? () => _handleSubmitted(_controller.text) 
                  : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget para mostrar un indicador de escritura ("typing indicator")
class TypingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  
  const TypingIndicator({
    super.key,
    this.color = AppTheme.coralMain,
    this.size = 6.0,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with TickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : AppTheme.lightGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              // Fases para cada punto, offset para animación en cascada
              final delay = index * 0.2;
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.translate(
                  offset: Offset(0, math.sin((_controller.value * 2 * math.pi) + delay) * 4),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Widget para crear una lista de mensajes de chat
class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController? scrollController;
  final Function(String)? onSuggestionTap;
  final Function(ChatMessage)? onActionExecute;
  final bool isLoading;
  
  const ChatMessageList({
    super.key,
    required this.messages,
    this.scrollController,
    this.onSuggestionTap,
    this.onActionExecute,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Lista de mensajes
        ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(8.0),
          reverse: false, // Mostrar los mensajes más recientes al final
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            
            return ChatBubble(
              message: message,
              onSuggestionTap: onSuggestionTap,
              onActionExecute: onActionExecute,
            );
          },
        ),
        
        // Indicador de escritura, si está cargando
        if (isLoading && shouldShowTypingIndicator())
          Positioned(
            bottom: 8,
            left: 52, // Alineado con el avatar del bot
            child: const TypingIndicator(),
          ),
      ],
    );
  }
  
  // Verificar si debemos mostrar el indicador de escritura
  bool shouldShowTypingIndicator() {
    if (!isLoading || messages.isEmpty) return false;
    
    // Verificamos si hay un mensaje "preliminar" del bot
    final lastMessages = messages.reversed.take(2).toList();
    if (lastMessages.isEmpty) return false;
    
    final lastMessage = lastMessages.first;
    return lastMessage.sender == MessageSender.bot && 
           (lastMessage.text.contains("...") || lastMessage.text.contains("Dame un momento"));
  }
}

/// Clase para animación de escritura a nivel de carácter (para efecto de typing)
class TypingTextAnimator extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;
  final VoidCallback? onComplete;
  
  const TypingTextAnimator({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
  });

  @override
  State<TypingTextAnimator> createState() => _TypingTextAnimatorState();
}

class _TypingTextAnimatorState extends State<TypingTextAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _displayedText = '';
  
  @override
  void initState() {
    super.initState();
    
    // Calcular duración basada en la longitud del texto
    final characterCount = widget.text.length;
    final typingDuration = Duration(
      milliseconds: (characterCount * 15).clamp(300, 3000)
    );
    
    _controller = AnimationController(
      vsync: this,
      duration: typingDuration,
    );
    
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        final textLength = (widget.text.length * _animation.value).round();
        final newText = widget.text.substring(0, textLength);
        
        if (newText != _displayedText) {
          setState(() {
            _displayedText = newText;
          });
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && widget.onComplete != null) {
          widget.onComplete!();
        }
      });
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}